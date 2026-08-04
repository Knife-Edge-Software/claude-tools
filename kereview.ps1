#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Reviews an issue worktree and records approval for its exact HEAD commit.

.DESCRIPTION
    Run with no arguments from an issue worktree, or provide an issue number
    from the original checkout. Claude is the default reviewer so Codex-authored
    changes receive a cross-model review.

.EXAMPLE
    kereview 42
    kereview 42 -With Codex
    kereview 42 -BaseBranch release/2.x
#>

param(
    [Parameter(Position=0)]
    [string]$Issue,

    [Parameter()]
    [ValidateSet('Claude', 'Codex')]
    [string]$With = 'Claude',

    [Parameter()]
    [string]$BaseBranch,

    [Parameter()]
    [switch]$Approve
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'agenttools-common.ps1')

$context = Get-AgentToolRepositoryContext
if ($Issue) {
    $issueNumber = @(ConvertTo-AgentToolIssueNumbers @($Issue))[0]
}
else {
    $issueNumber = Get-AgentToolCurrentIssueNumber -Context $context
}
$worktree = Get-AgentToolIssueWorktree -Context $context -Issue $issueNumber
$branchName = $worktree.Branch

if (-not $BaseBranch) {
    $metadata = Get-AgentToolIssueMetadata -Context $context -Issue $issueNumber
    if ($metadata -and $metadata.base_branch) {
        $BaseBranch = $metadata.base_branch
    }
}
if (-not $BaseBranch) {
    $BaseBranch = (& git -C $context.Root branch --show-current).Trim()
}
if (-not $BaseBranch) {
    throw "The original checkout is detached. Specify -BaseBranch explicitly."
}
if ($BaseBranch -eq $branchName) {
    throw "Base branch cannot be the issue branch '$branchName'."
}

& git -C $context.Root rev-parse --verify --quiet "$BaseBranch^{commit}" *> $null
if ($LASTEXITCODE -ne 0) {
    throw "Base branch or revision '$BaseBranch' does not exist."
}

$dirty = @(& git -C $worktree.Path status --porcelain)
if ($LASTEXITCODE -ne 0) {
    throw "Unable to inspect the issue worktree."
}
if ($dirty.Count -gt 0) {
    throw "The issue worktree has uncommitted changes. Commit or discard them before reviewing commits."
}

$head = (& git -C $worktree.Path rev-parse HEAD).Trim()
$commits = @(& git -C $worktree.Path log --oneline "$BaseBranch..HEAD")
if ($LASTEXITCODE -ne 0) {
    throw "Unable to compare '$branchName' with '$BaseBranch'."
}
if ($commits.Count -eq 0) {
    throw "Branch '$branchName' has no commits to review against '$BaseBranch'."
}

$reviewStatePath = Get-AgentToolReviewStatePath -Context $context -Issue $issueNumber
$reviewDirectory = Split-Path -Parent $reviewStatePath
[IO.Directory]::CreateDirectory($reviewDirectory) | Out-Null
$shortHead = $head.Substring(0, [Math]::Min(12, $head.Length))
$reportPath = Join-Path $reviewDirectory "issue-$issueNumber-$shortHead-$($With.ToLowerInvariant()).txt"

$state = [ordered]@{
    issue = [int]$issueNumber
    branch = $branchName
    head = $head
    base_branch = $BaseBranch
    reviewer = $With
    status = 'pending'
    reviewed_at_utc = $null
    report_path = $reportPath
}
Write-AgentToolJson -Path $reviewStatePath -Value $state

Write-Host "Reviewing issue #$issueNumber" -ForegroundColor Cyan
Write-Host "  Worktree: $($worktree.Path)" -ForegroundColor Gray
Write-Host "  Branch:   $branchName" -ForegroundColor Gray
Write-Host "  Base:     $BaseBranch" -ForegroundColor Gray
Write-Host "  HEAD:     $shortHead" -ForegroundColor Gray
Write-Host "  Reviewer: $With" -ForegroundColor Gray
Write-Host ''
Write-Host 'Commits under review:' -ForegroundColor Cyan
$commits | ForEach-Object { Write-Host "  $_" }
Write-Host ''

Push-Location $worktree.Path
try {
    if ($With -eq 'Claude') {
        Assert-AgentToolCommand claude
        & claude ultrareview $BaseBranch 2>&1 | Tee-Object -FilePath $reportPath
    }
    else {
        Assert-AgentToolCommand codex
        $reviewPrompt = 'Review for correctness, regressions, security problems, missing tests, and incomplete issue requirements. Report only actionable findings, ordered by severity, with file and line references.'
        & codex review --base $BaseBranch $reviewPrompt 2>&1 | Tee-Object -FilePath $reportPath
    }
    $reviewExitCode = $LASTEXITCODE
}
finally {
    Pop-Location
}

if ($reviewExitCode -ne 0) {
    $state.status = 'failed'
    $state.reviewed_at_utc = [DateTime]::UtcNow.ToString('o')
    Write-AgentToolJson -Path $reviewStatePath -Value $state
    throw "$With review failed with exit code $reviewExitCode. Report: $reportPath"
}

$approved = $Approve.IsPresent
if (-not $approved) {
    $answer = Read-Host 'Did the review pass with no unresolved findings? [y/N]'
    $approved = $answer -match '^(?i:y|yes)$'
}

$state.status = if ($approved) { 'approved' } else { 'rejected' }
$state.reviewed_at_utc = [DateTime]::UtcNow.ToString('o')
Write-AgentToolJson -Path $reviewStatePath -Value $state

if (-not $approved) {
    Write-Host "Review was not approved. Resolve the findings and run kereview $issueNumber again." -ForegroundColor Yellow
    Write-Host "Report: $reportPath" -ForegroundColor Gray
    exit 2
}

Write-Host ''
Write-Host "Approved $branchName at $shortHead." -ForegroundColor Green
Write-Host "Report: $reportPath" -ForegroundColor Gray
