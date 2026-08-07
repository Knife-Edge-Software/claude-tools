#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates an issue worktree and opens Codex, Claude, and PowerShell panes.

.DESCRIPTION
    Creates (or resumes) a sibling worktree named <repo>-issue-<first-issue>, then
    opens a three-column Windows Terminal tab:
    - Left pane: interactive Codex implementing the issues
    - Middle pane: interactive Claude for conversational review and QA handoff
    - Right pane: dependency setup followed by an interactive control shell

    The worktree is created by PowerShell rather than by the coding agent. This
    keeps worktree setup deterministic and lets Codex start in the correct root.

.PARAMETER Issues
    Issue numbers, separated by spaces and/or commas.

.EXAMPLE
    kebatchfix-codex 209 210
    kebatchfix-codex 1,2,3
#>

param(
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$Issues
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-Command {
    param([Parameter(Mandatory)][string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found on PATH."
    }
}

function Quote-PowerShellLiteral {
    param([Parameter(Mandatory)][string]$Value)

    return "'" + $Value.Replace("'", "''") + "'"
}

Assert-Command git
Assert-Command gh
Assert-Command codex
Assert-Command claude
Assert-Command wt

if (-not $Issues -or $Issues.Count -eq 0) {
    Write-Error "Usage: kebatchfix-codex <issue-numbers>"
    Write-Error "Example: kebatchfix-codex 209 210"
    exit 1
}

$allIssues = @(
    foreach ($argument in $Issues) {
        foreach ($candidate in ($argument -split ',')) {
            $number = $candidate.Trim().TrimStart('#')
            if ($number) {
                if ($number -notmatch '^\d+$') {
                    Write-Error "Invalid issue number: $candidate"
                    exit 1
                }
                $number
            }
        }
    }
)

if ($allIssues.Count -eq 0) {
    Write-Error "No issue numbers were provided."
    exit 1
}

$repoRootOutput = & git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0 -or -not $repoRootOutput) {
    Write-Error "Must be run from inside a Git repository."
    exit 1
}

$repoRoot = [IO.Path]::GetFullPath(($repoRootOutput | Select-Object -First 1).Trim())
$repoName = Split-Path -Leaf $repoRoot
$parentDir = Split-Path -Parent $repoRoot

# Git records absolute paths for linked worktrees. If the repository's parent
# directory was renamed or moved, repair sibling worktrees before attempting to
# enumerate them or run cleanup.
$worktreeListProbe = @(& git -C $repoRoot worktree list --porcelain 2>$null)
if ($LASTEXITCODE -ne 0) {
    $gitDirectory = (& git -C $repoRoot rev-parse --absolute-git-dir).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $gitDirectory) {
        Write-Error "Unable to resolve the repository's Git metadata directory."
        exit 1
    }

    $repairPaths = @(
        Get-ChildItem -LiteralPath (Join-Path $gitDirectory 'worktrees') -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $parentDir $_.Name } |
            Where-Object { Test-Path -LiteralPath (Join-Path $_ '.git') }
    )

    & git -C $repoRoot worktree repair @repairPaths
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Unable to repair Git worktree paths after the repository was moved."
        exit 1
    }

    # Entries whose worktrees no longer exist can retain absolute paths to the
    # old location and prevent Git from listing otherwise healthy worktrees.
    & git -C $repoRoot worktree prune
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Unable to prune stale Git worktree metadata."
        exit 1
    }

    $worktreeListProbe = @(& git -C $repoRoot worktree list --porcelain 2>$null)
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Git worktree metadata is still invalid after repair."
        exit 1
    }
}

# Finalized worktrees are retained while their model panes are open. Clean any
# prior finalized worktrees whose panes have since closed before starting more
# issue work.
$cleanupScriptPath = Join-Path $PSScriptRoot 'kecleanup.ps1'
if (Test-Path -LiteralPath $cleanupScriptPath) {
    Push-Location $repoRoot
    try {
        & $cleanupScriptPath -Quiet
    }
    finally {
        Pop-Location
    }
}

$baseBranch = (& git -C $repoRoot branch --show-current).Trim()
if ($LASTEXITCODE -ne 0 -or -not $baseBranch) {
    Write-Error "The original checkout must be on a branch before creating issue work."
    exit 1
}
$baseHead = (& git -C $repoRoot rev-parse HEAD).Trim()
$firstIssue = $allIssues[0]
$branchName = "issue-$firstIssue"
$worktreePath = Join-Path $parentDir "$repoName-issue-$firstIssue"
$issueList = $allIssues -join ', '
$issueReferences = ($allIssues | ForEach-Object { "#$_" }) -join ', '
$tabTitle = "#$firstIssue"

$registeredWorktrees = @(
    & git -C $repoRoot worktree list --porcelain |
        Where-Object { $_ -like 'worktree *' } |
        ForEach-Object { [IO.Path]::GetFullPath($_.Substring(9)) }
)
if ($LASTEXITCODE -ne 0) {
    Write-Error "Unable to inspect Git worktrees."
    exit 1
}

$resolvedTarget = [IO.Path]::GetFullPath($worktreePath)
$isRegisteredWorktree = $registeredWorktrees -contains $resolvedTarget
$createdWorktree = $false

if (Test-Path -LiteralPath $worktreePath) {
    if (-not $isRegisteredWorktree) {
        Write-Error "Target path already exists but is not a registered worktree: $worktreePath"
        exit 1
    }

    $existingBranch = (& git -C $worktreePath branch --show-current).Trim()
    if ($LASTEXITCODE -ne 0 -or $existingBranch -ne $branchName) {
        Write-Error "Existing worktree '$worktreePath' is on '$existingBranch', expected '$branchName'."
        exit 1
    }

    Write-Host "Resuming existing worktree: $worktreePath" -ForegroundColor Yellow
}
else {
    $matchingBranches = @(& git -C $repoRoot branch --list --format='%(refname:short)' -- $branchName)
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Unable to inspect existing branches."
        exit 1
    }
    $branchExists = $matchingBranches -contains $branchName

    if ($branchExists) {
        Write-Host "Creating worktree from existing branch $branchName..." -ForegroundColor Cyan
        & git -C $repoRoot worktree add $worktreePath $branchName
    }
    else {
        Write-Host "Creating worktree and branch $branchName from current HEAD..." -ForegroundColor Cyan
        & git -C $repoRoot worktree add $worktreePath -b $branchName
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create worktree: $worktreePath"
        exit 1
    }
    $createdWorktree = $true
}

# A linked worktree stores its index and branch metadata in the repository's
# common Git directory. Resolve it for the workflow metadata shared by the
# launcher, reviewer, and closer.
$gitCommonDirOutput = (& git -C $worktreePath rev-parse --git-common-dir).Trim()
if ($LASTEXITCODE -ne 0 -or -not $gitCommonDirOutput) {
    Write-Error "Unable to resolve the worktree's Git metadata directory."
    exit 1
}
if ([IO.Path]::IsPathRooted($gitCommonDirOutput)) {
    $gitCommonDir = [IO.Path]::GetFullPath($gitCommonDirOutput)
}
else {
    $gitCommonDir = [IO.Path]::GetFullPath((Join-Path $worktreePath $gitCommonDirOutput))
}

$issueMetadataDirectory = Join-Path (Join-Path $gitCommonDir 'agenttools') 'issues'
$issueMetadataPath = Join-Path $issueMetadataDirectory "issue-$firstIssue.json"
if ($createdWorktree -or -not (Test-Path -LiteralPath $issueMetadataPath)) {
    [IO.Directory]::CreateDirectory($issueMetadataDirectory) | Out-Null
    $issueMetadata = [ordered]@{
        issues = @($allIssues | ForEach-Object { [int]$_ })
        branch = $branchName
        worktree = $worktreePath
        base_branch = $baseBranch
        base_head = $baseHead
        status = 'active'
        created_at_utc = [DateTime]::UtcNow.ToString('o')
    }
    $issueMetadataJson = $issueMetadata | ConvertTo-Json -Depth 5
    [IO.File]::WriteAllText($issueMetadataPath, $issueMetadataJson, [Text.UTF8Encoding]::new($false))
}

$prompt = @"
Implement GitHub issues $issueReferences sequentially in this dedicated worktree.

For each issue:
1. Read the complete issue and all comments with `gh issue view <number> --comments`.
2. Find the implementation plan in the issue body or comments and identify every phase before changing code. Treat sufficiently detailed implementation steps or requirements in the issue body as the plan, even if they are not labeled "implementation plan" or repeated in a separate comment. Do not ask me to confirm that the issue body suffices; ask only if the issue body and comments together are missing a usable plan or are materially unclear.
3. Read and follow all applicable repository instructions, including AGENTS.md files.
4. Implement every phase, following existing project patterns. Keep unrelated changes untouched.
5. Run the most relevant focused tests and checks, then inspect the final diff.
6. Commit that issue separately with a message beginning `Fix #<number>:`.
7. Post a concise completion comment to the issue with the phases completed, tests run, changed files, branch $branchName, and commit hash. Identify it as generated by Codex.

Continue through all requested issues unless blocked. Do not push, merge, remove the worktree, or modify files in the original checkout. Preserve any pre-existing changes if this is a resumed worktree. At the end, summarize each issue's status and commit.
"@

$promptBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($prompt))
$quotedWorktree = Quote-PowerShellLiteral $worktreePath

$claudePrompt = @"
You are the independent reviewer and second collaborator for GitHub issues $issueReferences in worktree $worktreePath on branch $branchName, based on $baseBranch.

Stay conversational and wait for me to direct the review. When reviewing, read the issues and implementation plans, inspect the complete $baseBranch...HEAD change, run relevant checks, and report actionable correctness, regression, security, and test-coverage findings. Do not modify code unless I ask you to help fix something. You may use the GitHub CLI when I ask you to add a QA test plan, reopen an issue, or change its assignee.

The Codex pane is implementing the work. The PowerShell pane can run parameterless `keclose` from this worktree after we agree the exact HEAD is ready.
"@
$claudePromptBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($claudePrompt))

$lockDirectory = Join-Path (Join-Path (Join-Path $gitCommonDir 'agenttools') 'locks') "issue-$firstIssue"
[IO.Directory]::CreateDirectory($lockDirectory) | Out-Null
$quotedCodexLock = Quote-PowerShellLiteral (Join-Path $lockDirectory 'codex.lock')
$quotedClaudeLock = Quote-PowerShellLiteral (Join-Path $lockDirectory 'claude.lock')
$quotedShellLock = Quote-PowerShellLiteral (Join-Path $lockDirectory 'powershell.lock')

$codexScript = @"
`$global:AgentToolsPaneLock = [IO.File]::Open($quotedCodexLock, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::Read)
`$env:AGENTTOOLS_ISSUE = '$firstIssue'
`$prompt = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$promptBase64'))
& codex -C $quotedWorktree --yolo `$prompt
"@
$encodedCodexScript = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($codexScript))

$claudeScript = @"
`$global:AgentToolsPaneLock = [IO.File]::Open($quotedClaudeLock, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::Read)
`$env:AGENTTOOLS_ISSUE = '$firstIssue'
`$prompt = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$claudePromptBase64'))
& claude --dangerously-skip-permissions `$prompt
"@
$encodedClaudeScript = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($claudeScript))

$setupScript = @"
`$global:AgentToolsPaneLock = [IO.File]::Open($quotedShellLock, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::Read)
`$env:AGENTTOOLS_ISSUE = '$firstIssue'
Set-Location $quotedWorktree
Write-Host 'Worktree ready: $worktreePath' -ForegroundColor Green
Write-Host 'Branch: $branchName' -ForegroundColor Green
Write-Host 'Issues: $issueReferences' -ForegroundColor Green

if (Test-Path -LiteralPath 'package.json') {
    Write-Host ''
    Write-Host 'Running npm install...' -ForegroundColor Cyan
    npm install
}

if (Test-Path -LiteralPath 'src-tauri/Cargo.toml') {
    Write-Host ''
    Write-Host 'Fetching Rust dependencies...' -ForegroundColor Cyan
    Push-Location 'src-tauri'
    try {
        cargo fetch

        Write-Host ''
        Write-Host 'Running debug build...' -ForegroundColor Cyan
        cargo build
    }
    finally {
        Pop-Location
    }
}

Write-Host ''
Write-Host 'Setup complete. This shell is in the issue worktree.' -ForegroundColor Green
Write-Host 'After conversational review, run: keclose' -ForegroundColor Cyan
Write-Host 'Optional automated review remains available as: kereview' -ForegroundColor Gray
"@
$encodedSetupScript = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($setupScript))

Write-Host "Launching Windows Terminal tab: $tabTitle" -ForegroundColor Cyan
Write-Host "  Worktree: $worktreePath" -ForegroundColor Gray
Write-Host "  Branch:   $branchName" -ForegroundColor Gray
Write-Host "  Base:     $baseBranch" -ForegroundColor Gray
Write-Host "  Issues:   $issueList" -ForegroundColor Gray
Write-Host "  Left:     Codex (interactive, --yolo)" -ForegroundColor Gray
Write-Host "  Middle:   Claude (interactive reviewer)" -ForegroundColor Gray
Write-Host "  Right:    dependency setup and control shell" -ForegroundColor Gray
Write-Host "  Finalize: keclose (no arguments, from the worktree shell)" -ForegroundColor Gray

wt -w 0 new-tab --title $tabTitle --suppressApplicationTitle -d $worktreePath -- powershell -NoExit -EncodedCommand $encodedCodexScript `; split-pane -V --size .67 --suppressApplicationTitle -d $worktreePath -- powershell -NoExit -EncodedCommand $encodedClaudeScript `; split-pane -V --size .5 --suppressApplicationTitle -d $worktreePath -- powershell -NoExit -EncodedCommand $encodedSetupScript
