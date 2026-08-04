#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Merges a reviewed issue worktree, pushes, closes issues, and cleans up.

.DESCRIPTION
    Run from the original repository checkout. The first issue number locates
    the issue branch/worktree; every supplied issue number is closed after the
    merge is pushed successfully.

.EXAMPLE
    keclose 42
    keclose 42 43 44
    keclose 42 -Into release/2.x
#>

param(
    [Parameter()]
    [string]$Into,

    [Parameter()]
    [switch]$SkipReview,

    [Parameter()]
    [switch]$Yes,

    [Parameter(Position=0, ValueFromRemainingArguments)]
    [string[]]$Issues
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'agenttools-common.ps1')

Assert-AgentToolCommand gh

if (-not $Issues -or $Issues.Count -eq 0) {
    Write-Error 'Usage: keclose <issue-numbers> [-Into <branch>] [-SkipReview] [-Yes]'
    exit 1
}

$issueNumbers = @(ConvertTo-AgentToolIssueNumbers $Issues)
$firstIssue = $issueNumbers[0]
$context = Get-AgentToolRepositoryContext
$worktree = Get-AgentToolIssueWorktree -Context $context -Issue $firstIssue
$branchName = $worktree.Branch

if (-not $Into) {
    $metadataPath = Get-AgentToolIssueMetadataPath -Context $context -Issue $firstIssue
    if (Test-Path -LiteralPath $metadataPath) {
        try {
            $metadata = Get-Content -Raw -LiteralPath $metadataPath | ConvertFrom-Json
            if ($metadata.base_branch) {
                $Into = $metadata.base_branch
            }
        }
        catch {
            Write-Warning "Ignoring unreadable issue metadata at '$metadataPath'."
        }
    }
}
if (-not $Into) {
    $Into = (& git -C $context.Root branch --show-current).Trim()
}
if (-not $Into) {
    throw 'The original checkout is detached. Specify -Into explicitly.'
}

$currentBranch = (& git -C $context.Root branch --show-current).Trim()
if ($currentBranch -ne $Into) {
    throw "The original checkout must be on target branch '$Into'; it is currently on '$currentBranch'."
}
if ($Into -eq $branchName) {
    throw "Target branch cannot be the issue branch '$branchName'."
}

$mainDirty = @(& git -C $context.Root status --porcelain)
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to inspect the original checkout.'
}
if ($mainDirty.Count -gt 0) {
    throw "The original checkout has uncommitted changes. Clean it before closing the issue worktree."
}

$worktreeDirty = @(& git -C $worktree.Path status --porcelain)
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to inspect the issue worktree.'
}
if ($worktreeDirty.Count -gt 0) {
    throw "The issue worktree has uncommitted changes. Commit or discard them before closing."
}

$head = (& git -C $worktree.Path rev-parse HEAD).Trim()
$shortHead = $head.Substring(0, [Math]::Min(12, $head.Length))
$reviewState = $null
if (-not $SkipReview) {
    $reviewStatePath = Get-AgentToolReviewStatePath -Context $context -Issue $firstIssue
    if (-not (Test-Path -LiteralPath $reviewStatePath)) {
        throw "No approved review was found. Run 'kereview $firstIssue' first, or use -SkipReview explicitly."
    }
    try {
        $reviewState = Get-Content -Raw -LiteralPath $reviewStatePath | ConvertFrom-Json
    }
    catch {
        throw "Review state is unreadable: $reviewStatePath"
    }

    if ($reviewState.status -ne 'approved') {
        throw "The latest review status is '$($reviewState.status)', not 'approved'. Run 'kereview $firstIssue' again."
    }
    if ($reviewState.branch -ne $branchName -or $reviewState.head -ne $head) {
        throw "Branch HEAD changed after review. Reviewed '$($reviewState.head)'; current '$head'. Run 'kereview $firstIssue' again."
    }
    if ($reviewState.base_branch -ne $Into) {
        throw "The branch was reviewed against '$($reviewState.base_branch)', but would merge into '$Into'. Review it against the intended target."
    }
}

$commits = @(& git -C $context.Root log --oneline "$Into..$branchName")
if ($LASTEXITCODE -ne 0) {
    throw "Unable to compare '$branchName' with '$Into'."
}
if ($commits.Count -eq 0) {
    Write-Warning "No unmerged commits were found on '$branchName' relative to '$Into'. The script will continue so an interrupted close can be retried."
}

& git -C $context.Root remote get-url origin *> $null
if ($LASTEXITCODE -ne 0) {
    throw "Remote 'origin' is required for fetch and push."
}

Write-Host "Ready to close issue work" -ForegroundColor Cyan
Write-Host "  Original:  $($context.Root)" -ForegroundColor Gray
Write-Host "  Worktree:  $($worktree.Path)" -ForegroundColor Gray
Write-Host "  Merge:     $branchName -> $Into" -ForegroundColor Gray
Write-Host "  HEAD:      $shortHead" -ForegroundColor Gray
Write-Host "  Issues:    $(($issueNumbers | ForEach-Object { "#$_" }) -join ', ')" -ForegroundColor Gray
if ($reviewState) {
    Write-Host "  Reviewed:  $($reviewState.reviewer) at $($reviewState.reviewed_at_utc)" -ForegroundColor Gray
}
elseif ($SkipReview) {
    Write-Host '  Reviewed:  SKIPPED explicitly' -ForegroundColor Yellow
}
Write-Host ''
if ($commits.Count -gt 0) {
    Write-Host 'Commits to merge:' -ForegroundColor Cyan
    $commits | ForEach-Object { Write-Host "  $_" }
    Write-Host ''
}
Write-Host "This will update $Into, push it to origin, close the issues, remove the worktree, and delete $branchName." -ForegroundColor Yellow

if (-not $Yes) {
    $answer = Read-Host 'Continue? [y/N]'
    if ($answer -notmatch '^(?i:y|yes)$') {
        Write-Host 'Close cancelled. No changes were made.' -ForegroundColor Yellow
        exit 2
    }
}

Write-Host "Fetching origin/$Into..." -ForegroundColor Cyan
& git -C $context.Root fetch origin $Into
if ($LASTEXITCODE -ne 0) {
    throw "Fetch failed; nothing was merged."
}

Write-Host "Fast-forwarding $Into from origin/$Into when needed..." -ForegroundColor Cyan
& git -C $context.Root merge --ff-only "origin/$Into"
if ($LASTEXITCODE -ne 0) {
    throw "Target branch '$Into' has diverged from 'origin/$Into'. Resolve that before closing."
}

Write-Host "Merging $branchName into $Into..." -ForegroundColor Cyan
& git -C $context.Root merge --no-ff --no-edit $branchName
if ($LASTEXITCODE -ne 0) {
    throw "Merge failed. Resolve or abort the merge in '$($context.Root)'; the worktree was preserved."
}

$mergeHead = (& git -C $context.Root rev-parse HEAD).Trim()
$shortMergeHead = $mergeHead.Substring(0, [Math]::Min(12, $mergeHead.Length))

Write-Host "Pushing $Into to origin..." -ForegroundColor Cyan
& git -C $context.Root push origin $Into
if ($LASTEXITCODE -ne 0) {
    throw "Push failed. The local merge was preserved; issues remain open and the worktree was not removed."
}

foreach ($issueNumber in $issueNumbers) {
    $state = (& gh issue view $issueNumber --json state --jq '.state').Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to read GitHub issue #$issueNumber. The merge is pushed, but cleanup was stopped."
    }
    if ($state -eq 'CLOSED') {
        Write-Host "Issue #$issueNumber is already closed." -ForegroundColor Yellow
        continue
    }

    $comment = "Resolved by commit $shortMergeHead on branch $Into. Implementation branch $branchName was reviewed at $shortHead before merge."
    & gh issue close $issueNumber --comment $comment
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to close GitHub issue #$issueNumber. The merge is pushed, but cleanup was stopped."
    }
}

Write-Host "Removing worktree $($worktree.Path)..." -ForegroundColor Cyan
& git -C $context.Root worktree remove $worktree.Path
if ($LASTEXITCODE -ne 0) {
    throw "Issue changes are merged and pushed, but worktree removal failed: $($worktree.Path)"
}

Write-Host "Deleting merged branch $branchName..." -ForegroundColor Cyan
& git -C $context.Root branch -d $branchName
if ($LASTEXITCODE -ne 0) {
    throw "Worktree was removed, but merged branch deletion failed: $branchName"
}

Write-Host ''
Write-Host "Closed $(($issueNumbers | ForEach-Object { "#$_" }) -join ', ') at $shortMergeHead." -ForegroundColor Green
