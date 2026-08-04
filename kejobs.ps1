#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Runs keclaude for multiple issues, saving output to files.

.PARAMETER Milestone
    Fetch issues from this GitHub milestone

.PARAMETER Issues
    Comma-separated list of issue numbers

.PARAMETER Command
    The Claude command to run (everything after the flags)

.PARAMETER Timeout
    Timeout in seconds for each job (default: 600 = 10 minutes)

.EXAMPLE
    kejobs -milestone foo "/ke:plan"
    kejobs -issues 7,12,25 "/ke:plan"
#>

param(
    [Parameter()]
    [string]$Milestone,

    [Parameter()]
    [string]$Issues,

    [Parameter()]
    [int]$Timeout = 600,

    [Parameter(Position=0, ValueFromRemainingArguments)]
    [string[]]$Command
)

$ErrorActionPreference = "Stop"

# Validate inputs
if (-not $Milestone -and -not $Issues) {
    Write-Error "Must specify either -milestone or -issues"
    Write-Host "Usage: kejobs -milestone <name> <command>"
    Write-Host "       kejobs -issues 1,2,3 <command>"
    exit 1
}

if (-not $Command) {
    Write-Error "Must specify a command to run (e.g., /ke:plan)"
    exit 1
}

$commandStr = $Command -join ' '

# Get issue numbers
$issueNumbers = @()

if ($Milestone) {
    Write-Host "Fetching issues from milestone: $Milestone" -ForegroundColor Cyan

    # Use gh CLI to get issues in milestone
    $ghOutput = gh issue list --milestone $Milestone --state open --json number --limit 100 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to fetch issues from milestone: $ghOutput"
        exit 1
    }

    try {
        $issuesJson = $ghOutput | ConvertFrom-Json
        $issueNumbers = $issuesJson | ForEach-Object { $_.number }
    }
    catch {
        Write-Error "Failed to parse gh output: $_"
        exit 1
    }

    if ($issueNumbers.Count -eq 0) {
        Write-Host "No open issues found in milestone '$Milestone'" -ForegroundColor Yellow
        exit 0
    }
}
else {
    # Parse comma-separated issue numbers
    try {
        $issueNumbers = $Issues -split ',' | ForEach-Object {
            $trimmed = $_.Trim()
            if (-not $trimmed) { return }
            [int]$trimmed
        }
    }
    catch {
        Write-Error "Invalid issue number in '$Issues'. Must be comma-separated integers."
        exit 1
    }

    if ($issueNumbers.Count -eq 0) {
        Write-Error "No valid issue numbers provided"
        exit 1
    }
}

Write-Host "Running '$commandStr' for issues: $($issueNumbers -join ', ')" -ForegroundColor Cyan
Write-Host ""

# Get path to keclaude (same directory as this script)
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$keclaudePath = Join-Path $scriptDir "keclaude.ps1"

if (-not (Test-Path $keclaudePath)) {
    Write-Error "keclaude.ps1 not found at: $keclaudePath"
    exit 1
}

# Run keclaude for each issue
$jobs = @()
foreach ($issueNum in $issueNumbers) {
    $outputFile = "kejobs_output_$issueNum.md"

    Write-Host "Starting: $commandStr $issueNum -> $outputFile" -ForegroundColor Gray

    # Start as background job (pass working directory since jobs start in default location)
    $workDir = (Get-Location).Path
    $job = Start-Job -ScriptBlock {
        param($keclaude, $cmd, $issue, $outFile, $dir)
        Set-Location $dir
        & powershell -File $keclaude $cmd $issue > $outFile 2>&1
        return $LASTEXITCODE
    } -ArgumentList $keclaudePath, $commandStr, $issueNum, (Join-Path $workDir $outputFile), $workDir

    $jobs += @{
        Job = $job
        Issue = $issueNum
        OutputFile = $outputFile
    }
}

# Wait for all jobs and report results
Write-Host ""
Write-Host "Waiting for jobs to complete (timeout: ${Timeout}s per job)..." -ForegroundColor Cyan

$results = @()
foreach ($jobInfo in $jobs) {
    $completed = Wait-Job -Job $jobInfo.Job -Timeout $Timeout

    if (-not $completed) {
        # Job timed out
        Stop-Job -Job $jobInfo.Job
        Remove-Job -Job $jobInfo.Job -Force
        Write-Host "  Issue #$($jobInfo.Issue): TIMEOUT -> $($jobInfo.OutputFile)" -ForegroundColor Yellow
        $results += 1
    }
    else {
        $result = Receive-Job -Job $jobInfo.Job
        Remove-Job -Job $jobInfo.Job

        $status = if ($result -eq 0) { "OK" } else { "FAILED" }
        $color = if ($result -eq 0) { "Green" } else { "Red" }

        Write-Host "  Issue #$($jobInfo.Issue): $status -> $($jobInfo.OutputFile)" -ForegroundColor $color
        $results += $result
    }
}

Write-Host ""
Write-Host "Done. Output files created in current directory." -ForegroundColor Green

# Exit with error if any job failed
$failCount = ($results | Where-Object { $_ -ne 0 }).Count
if ($failCount -gt 0) {
    exit 1
}
