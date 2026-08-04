#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Finalizes the current issue worktree without ending its model sessions.

.DESCRIPTION
    Run with no arguments from an issue worktree. The script infers the full
    issue batch, branch, worktree, and base branch from agenttools metadata. It
    confirms conversational review, merges and pushes, then lets you close the
    issues, keep them open for QA, or leave their state unchanged.

    Worktree cleanup is deferred until all terminal panes have closed.

.EXAMPLE
    keclose
    keclose -Disposition QA -Assignee tester-name
    keclose 42 43 -Disposition Close
#>

param(
    [Parameter()]
    [string]$Into,

    [Parameter()]
    [ValidateSet('Close', 'QA', 'Unchanged')]
    [string]$Disposition,

    [Parameter()]
    [string]$Assignee,

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
$context = Get-AgentToolRepositoryContext

if ($Issues -and $Issues.Count -gt 0) {
    $issueNumbers = @(ConvertTo-AgentToolIssueNumbers $Issues)
    $firstIssue = $issueNumbers[0]
}
else {
    if ($context.CurrentWorktree.Branch -match '^issue-(\d+)$') {
        $firstIssue = $Matches[1]
    }
    elseif ($env:AGENTTOOLS_ISSUE) {
        $firstIssue = @(ConvertTo-AgentToolIssueNumbers @($env:AGENTTOOLS_ISSUE))[0]
    }
    else {
        throw 'No issue context is available. Run keclose from an issue worktree or supply an issue number explicitly.'
    }
    $metadataForIssues = Get-AgentToolIssueMetadata -Context $context -Issue $firstIssue
    if ($metadataForIssues -and @($metadataForIssues.issues).Count -gt 0) {
        $issueNumbers = @($metadataForIssues.issues | ForEach-Object { [string]$_ })
    }
    else {
        $issueNumbers = @($firstIssue)
    }
}

$worktree = Get-AgentToolIssueWorktree -Context $context -Issue $firstIssue
$branchName = $worktree.Branch
$env:AGENTTOOLS_ISSUE = $firstIssue
$metadataPath = Get-AgentToolIssueMetadataPath -Context $context -Issue $firstIssue
$metadata = Get-AgentToolIssueMetadata -Context $context -Issue $firstIssue

if (-not $Into -and $metadata -and $metadata.base_branch) {
    $Into = [string]$metadata.base_branch
}
if (-not $Into) {
    $Into = (& git -C $context.Root branch --show-current).Trim()
}
if (-not $Into) {
    throw 'The original checkout is detached. Specify -Into explicitly.'
}
if ($Into -eq $branchName) {
    throw "Target branch cannot be the issue branch '$branchName'."
}

$currentBranch = (& git -C $context.Root branch --show-current).Trim()
if ($currentBranch -ne $Into) {
    throw "The original checkout must be on target branch '$Into'; it is currently on '$currentBranch'."
}

# Move the control shell out of the issue worktree before finalization. This
# change persists in the calling PowerShell session and avoids locking the
# worktree from the control pane.
if (-not $context.IsPrimary) {
    if (-not $context.CurrentRoot.Equals($worktree.Path, [StringComparison]::OrdinalIgnoreCase)) {
        throw "This shell is in a different linked worktree. Run keclose from '$($worktree.Path)' or '$($context.Root)'."
    }
    Set-Location -LiteralPath $context.Root
    Write-Host "Control shell moved to original checkout: $($context.Root)" -ForegroundColor Cyan
}

$mainDirty = @(& git -C $context.Root status --porcelain)
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to inspect the original checkout.'
}
if ($mainDirty.Count -gt 0) {
    throw 'The original checkout has uncommitted changes. Clean it before finalizing the issue worktree.'
}

$worktreeDirty = @(& git -C $worktree.Path status --porcelain)
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to inspect the issue worktree.'
}
if ($worktreeDirty.Count -gt 0) {
    throw 'The issue worktree has uncommitted changes. Commit or discard them before finalizing.'
}

$head = (& git -C $worktree.Path rev-parse HEAD).Trim()
$shortHead = $head.Substring(0, [Math]::Min(12, $head.Length))
$reviewStatePath = Get-AgentToolReviewStatePath -Context $context -Issue $firstIssue
$reviewState = $null
$reviewMatchesHead = $false
if (Test-Path -LiteralPath $reviewStatePath) {
    try {
        $reviewState = Get-Content -Raw -LiteralPath $reviewStatePath | ConvertFrom-Json
        $reviewMatchesHead = (
            $reviewState.status -eq 'approved' -and
            $reviewState.branch -eq $branchName -and
            $reviewState.head -eq $head -and
            $reviewState.base_branch -eq $Into
        )
    }
    catch {
        Write-Warning "Ignoring unreadable review state at '$reviewStatePath'."
        $reviewState = $null
    }
}

$commits = @(& git -C $context.Root log --oneline "$Into..$branchName")
if ($LASTEXITCODE -ne 0) {
    throw "Unable to compare '$branchName' with '$Into'."
}
if ($commits.Count -eq 0) {
    Write-Warning "No unmerged commits were found on '$branchName' relative to '$Into'. Finalization can continue after an interrupted prior run."
}

& git -C $context.Root remote get-url origin *> $null
if ($LASTEXITCODE -ne 0) {
    throw "Remote 'origin' is required for fetch and push."
}

Write-Host 'Ready to finalize issue work' -ForegroundColor Cyan
Write-Host "  Original:  $($context.Root)" -ForegroundColor Gray
Write-Host "  Worktree:  $($worktree.Path)" -ForegroundColor Gray
Write-Host "  Merge:     $branchName -> $Into" -ForegroundColor Gray
Write-Host "  HEAD:      $shortHead" -ForegroundColor Gray
Write-Host "  Issues:    $(($issueNumbers | ForEach-Object { "#$_" }) -join ', ')" -ForegroundColor Gray
if ($reviewMatchesHead) {
    Write-Host "  Reviewed:  $($reviewState.reviewer) at $($reviewState.reviewed_at_utc)" -ForegroundColor Green
}
elseif ($SkipReview) {
    Write-Host '  Reviewed:  skipped explicitly' -ForegroundColor Yellow
}
else {
    Write-Host '  Reviewed:  conversational confirmation required' -ForegroundColor Yellow
}
Write-Host ''
if ($commits.Count -gt 0) {
    Write-Host 'Commits to merge:' -ForegroundColor Cyan
    $commits | ForEach-Object { Write-Host "  $_" }
    Write-Host ''
}

if (-not $reviewMatchesHead -and -not $SkipReview) {
    if ($Yes) {
        throw 'No matching review approval exists. Remove -Yes to confirm conversational review, or use -SkipReview explicitly.'
    }
    $reviewAnswer = Read-Host "Has exact HEAD $shortHead been reviewed with no unresolved findings? [y/N]"
    if ($reviewAnswer -notmatch '^(?i:y|yes)$') {
        Write-Host 'Finalization cancelled. Resolve the review findings and try again.' -ForegroundColor Yellow
        exit 2
    }

    $reviewState = [ordered]@{
        issue = [int]$firstIssue
        branch = $branchName
        head = $head
        base_branch = $Into
        reviewer = 'Conversational'
        status = 'approved'
        reviewed_at_utc = [DateTime]::UtcNow.ToString('o')
        report_path = $null
    }
    Write-AgentToolJson -Path $reviewStatePath -Value $reviewState
    $reviewMatchesHead = $true
}

if (-not $Disposition) {
    if ($Yes) {
        $Disposition = 'Close'
    }
    else {
        Write-Host ''
        Write-Host 'What should happen to the GitHub issues after the merge?' -ForegroundColor Cyan
        Write-Host '  1. Close as resolved'
        Write-Host '  2. Keep open for QA'
        Write-Host '  3. Leave issue state unchanged'
        $choice = Read-Host 'Choose 1, 2, or 3'
        $Disposition = switch ($choice) {
            '1' { 'Close' }
            '2' { 'QA' }
            '3' { 'Unchanged' }
            default { throw "Invalid issue disposition choice: $choice" }
        }
    }
}

if ($Disposition -eq 'QA' -and -not $Assignee -and -not $Yes) {
    $Assignee = Read-Host 'QA assignee GitHub username (blank to leave assignment unchanged)'
}

Write-Host ''
Write-Host "Disposition: $Disposition" -ForegroundColor Cyan
if ($Disposition -eq 'QA' -and $Assignee) {
    Write-Host "QA assignee: $Assignee" -ForegroundColor Cyan
}
Write-Host "This will update $Into and push it to origin. The worktree will remain available while the model panes are open." -ForegroundColor Yellow

if (-not $Yes) {
    $answer = Read-Host 'Continue? [y/N]'
    if ($answer -notmatch '^(?i:y|yes)$') {
        Write-Host 'Finalization cancelled. No merge was performed.' -ForegroundColor Yellow
        exit 2
    }
}

Write-Host "Fetching origin/$Into..." -ForegroundColor Cyan
& git -C $context.Root fetch origin $Into
if ($LASTEXITCODE -ne 0) {
    throw 'Fetch failed; nothing was merged.'
}

Write-Host "Fast-forwarding $Into from origin/$Into when needed..." -ForegroundColor Cyan
& git -C $context.Root merge --ff-only "origin/$Into"
if ($LASTEXITCODE -ne 0) {
    throw "Target branch '$Into' has diverged from 'origin/$Into'. Resolve that before finalizing."
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
    throw 'Push failed. The local merge and issue worktree were preserved; GitHub issues were not changed.'
}

foreach ($issueNumber in $issueNumbers) {
    if ($Disposition -eq 'Unchanged') {
        continue
    }

    $issueState = (& gh issue view $issueNumber --json state --jq '.state').Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to read GitHub issue #$issueNumber. The merge is pushed, but issue updates stopped."
    }

    if ($Disposition -eq 'Close') {
        if ($issueState -eq 'CLOSED') {
            Write-Host "Issue #$issueNumber is already closed." -ForegroundColor Yellow
            continue
        }
        $comment = "Resolved by commit $shortMergeHead on branch $Into after review of implementation HEAD $shortHead."
        & gh issue close $issueNumber --comment $comment
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to close GitHub issue #$issueNumber. The merge is pushed, but finalization metadata was not updated."
        }
    }
    elseif ($Disposition -eq 'QA') {
        if ($issueState -eq 'CLOSED') {
            & gh issue reopen $issueNumber
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to reopen GitHub issue #$issueNumber for QA."
            }
        }
        if ($Assignee) {
            & gh issue edit $issueNumber --add-assignee $Assignee
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to assign GitHub issue #$issueNumber to '$Assignee'."
            }
        }
        $comment = "Implementation merged as $shortMergeHead on $Into. This issue remains open for QA; a conversational agent can add the detailed test plan."
        & gh issue comment $issueNumber --body $comment
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to add the QA handoff comment to GitHub issue #$issueNumber."
        }
    }
}

if (-not $metadata) {
    $metadata = [pscustomobject]@{
        issues = @($issueNumbers | ForEach-Object { [int]$_ })
        branch = $branchName
        worktree = $worktree.Path
        base_branch = $Into
    }
}
$metadata | Add-Member -NotePropertyName status -NotePropertyValue 'finalized' -Force
$metadata | Add-Member -NotePropertyName disposition -NotePropertyValue $Disposition.ToLowerInvariant() -Force
$metadata | Add-Member -NotePropertyName implementation_head -NotePropertyValue $head -Force
$metadata | Add-Member -NotePropertyName merge_head -NotePropertyValue $mergeHead -Force
$metadata | Add-Member -NotePropertyName finalized_at_utc -NotePropertyValue ([DateTime]::UtcNow.ToString('o')) -Force
Write-AgentToolJson -Path $metadataPath -Value $metadata

Write-Host ''
Write-Host "Finalized $(($issueNumbers | ForEach-Object { "#$_" }) -join ', ') at $shortMergeHead." -ForegroundColor Green
Write-Host 'The worktree is intentionally retained so the Codex and Claude conversations can continue.' -ForegroundColor Green
Write-Host 'After closing this terminal tab, run kecleanup from the original checkout, or let the next kebatchfix-codex run clean it automatically.' -ForegroundColor Gray
if ($Disposition -eq 'QA') {
    Write-Host 'Ask Claude or Codex to add the detailed QA test plan while the conversation is still open.' -ForegroundColor Cyan
}
