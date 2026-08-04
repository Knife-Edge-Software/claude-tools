<#
.SYNOPSIS
    Orchestrates batch execution of GitHub issues across multiple terminals.

.DESCRIPTION
    This script manages parallel execution of issue tracks, monitoring completion
    and triggering dependent work when ready.

.PARAMETER ConfigPath
    Path to the batch configuration JSON file (ke-batch-state/config.json)

.PARAMETER PollInterval
    Seconds between status checks (default: 10)

.EXAMPLE
    .\ke-orchestrator.ps1 -ConfigPath "ke-batch-state/config.json"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ConfigPath,

    [int]$PollInterval = 10
)

$ErrorActionPreference = "Stop"

# Colors for output
function Write-Status { param($msg) Write-Host "[STATUS] $msg" -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host "[SUCCESS] $msg" -ForegroundColor Green }
function Write-Warning { param($msg) Write-Host "[WARNING] $msg" -ForegroundColor Yellow }
function Write-Error { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }

# Load configuration
function Get-Config {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        throw "Config file not found: $Path"
    }

    return Get-Content $Path -Raw | ConvertFrom-Json
}

# Update state file
function Set-TrackStatus {
    param(
        [string]$StateDir,
        [string]$TrackId,
        [string]$Status,
        [int]$CurrentIssue = $null
    )

    $trackDir = Join-Path $StateDir "track-$TrackId"
    if (-not (Test-Path $trackDir)) {
        New-Item -ItemType Directory -Path $trackDir -Force | Out-Null
    }

    Set-Content -Path (Join-Path $trackDir "status.txt") -Value $Status

    if ($CurrentIssue) {
        Set-Content -Path (Join-Path $trackDir "current-issue.txt") -Value $CurrentIssue
    }
}

# Read track status
function Get-TrackStatus {
    param(
        [string]$StateDir,
        [string]$TrackId
    )

    $statusFile = Join-Path $StateDir "track-$TrackId" "status.txt"
    if (Test-Path $statusFile) {
        return (Get-Content $statusFile -Raw).Trim()
    }
    return "unknown"
}

# Launch a Claude session in Windows Terminal
function Start-ClaudeSession {
    param(
        [string]$WorktreePath,
        [string]$TrackId,
        [string]$TrackName,
        [int[]]$Issues,
        [string]$StateDir
    )

    $issueList = $Issues -join " "
    $stateAbsPath = (Resolve-Path $StateDir).Path

    # Build the Claude command
    # After branchfix completes, signal completion
    $prompt = "/ke:branchfix $issueList"

    # Create a wrapper script that runs Claude and then signals completion
    $wrapperScript = @"
cd `"$WorktreePath`"
Write-Host "Starting Track $TrackId ($TrackName): Issues $issueList"
Write-Host "============================================"

# Run Claude
claude -p "$prompt"

# Signal completion (will be done by /ke:close or manually)
Write-Host ""
Write-Host "Track $TrackId complete. Press any key to close..."
`$null = `$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
"@

    $wrapperPath = Join-Path $stateAbsPath "track-$TrackId-runner.ps1"
    Set-Content -Path $wrapperPath -Value $wrapperScript

    # Launch in new Windows Terminal tab
    $wtArgs = @(
        "-w", "0",           # Current window
        "nt",                # New tab
        "-d", $WorktreePath, # Working directory
        "--title", "Track $TrackId - $TrackName",
        "powershell", "-ExecutionPolicy", "Bypass", "-File", $wrapperPath
    )

    Write-Status "Launching Terminal for Track $TrackId ($TrackName)..."
    Start-Process "wt" -ArgumentList $wtArgs

    Set-TrackStatus -StateDir $StateDir -TrackId $TrackId -Status "running" -CurrentIssue $Issues[0]
}

# Check if a track has completed (by checking for completion signals)
function Test-TrackComplete {
    param(
        [string]$StateDir,
        [string]$TrackId
    )

    $status = Get-TrackStatus -StateDir $StateDir -TrackId $TrackId
    return ($status -eq "complete")
}

# Main orchestration loop
function Start-Orchestration {
    param($Config)

    $stateDir = $Config.state_dir
    $repoPath = $Config.repo_path
    $tracks = $Config.tracks

    Write-Status "Starting batch orchestration..."
    Write-Status "Repository: $repoPath"
    Write-Status "State directory: $stateDir"
    Write-Status "Tracks: $($tracks.Count)"

    # Initialize all tracks
    foreach ($track in $tracks) {
        Set-TrackStatus -StateDir $stateDir -TrackId $track.id -Status "pending"
    }

    # Update main state
    $mainState = @{
        status = "running"
        started_at = (Get-Date -Format "o")
        tracks_total = $tracks.Count
        tracks_complete = 0
    }
    Set-Content -Path (Join-Path $stateDir "state.json") -Value ($mainState | ConvertTo-Json)

    # Launch all root tracks (those that start from main)
    foreach ($track in $tracks) {
        $worktreePath = Join-Path (Split-Path $repoPath -Parent) (Split-Path $track.worktree -Leaf)

        Start-ClaudeSession `
            -WorktreePath $worktreePath `
            -TrackId $track.id `
            -TrackName $track.name `
            -Issues $track.issues `
            -StateDir $stateDir

        # Small delay between launches to avoid terminal conflicts
        Start-Sleep -Seconds 2
    }

    Write-Success "All tracks launched!"
    Write-Status ""
    Write-Status "Monitoring progress... (Press Ctrl+C to stop monitoring)"
    Write-Status ""

    # Monitor loop
    $allComplete = $false
    while (-not $allComplete) {
        $completeCount = 0
        $statusTable = @()

        foreach ($track in $tracks) {
            $status = Get-TrackStatus -StateDir $stateDir -TrackId $track.id
            $currentIssueFile = Join-Path $stateDir "track-$($track.id)" "current-issue.txt"
            $currentIssue = if (Test-Path $currentIssueFile) { (Get-Content $currentIssueFile -Raw).Trim() } else { "-" }

            $statusTable += [PSCustomObject]@{
                Track = $track.id
                Name = $track.name
                Status = $status
                CurrentIssue = $currentIssue
            }

            if ($status -eq "complete") {
                $completeCount++
            }
        }

        # Display status
        Clear-Host
        Write-Host ('=' * 64) -ForegroundColor Cyan
        Write-Host '              KE BATCH ORCHESTRATOR' -ForegroundColor Cyan
        Write-Host ('-' * 64) -ForegroundColor Cyan
        Write-Host "Progress: $completeCount / $($tracks.Count) tracks complete" -ForegroundColor Cyan
        Write-Host ('=' * 64) -ForegroundColor Cyan
        Write-Host ""

        $statusTable | Format-Table -AutoSize

        Write-Host ""
        Write-Host "Last updated: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Gray
        Write-Host "Press Ctrl+C to stop monitoring (tracks will continue running)" -ForegroundColor Gray

        if ($completeCount -eq $tracks.Count) {
            $allComplete = $true
        } else {
            Start-Sleep -Seconds $PollInterval
        }
    }

    # All complete
    Write-Host ""
    Write-Success ('=' * 64)
    Write-Success "  ALL TRACKS COMPLETE!"
    Write-Success ('=' * 64)
    Write-Host ""
    Write-Status "Next steps:"
    Write-Host "  1. Review changes in each worktree"
    Write-Host "  2. Test the leaf nodes of each chain"
    Write-Host "  3. Run '/ke:cascade' to merge everything back to main"
    Write-Host ""

    # Update main state
    $mainState = @{
        status = "complete"
        started_at = $mainState.started_at
        completed_at = (Get-Date -Format "o")
        tracks_total = $tracks.Count
        tracks_complete = $completeCount
    }
    Set-Content -Path (Join-Path $stateDir "state.json") -Value ($mainState | ConvertTo-Json)
}

# Entry point
try {
    $config = Get-Config -Path $ConfigPath
    Start-Orchestration -Config $config
}
catch {
    Write-Error "Orchestration failed: $_"
    exit 1
}
