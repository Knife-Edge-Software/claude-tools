#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates an issue worktree and opens Codex plus a setup shell in Windows Terminal.

.DESCRIPTION
    Creates (or resumes) a sibling worktree named <repo>-issue-<first-issue>, then
    opens a split Windows Terminal tab:
    - Left pane: interactive Codex, instructed to implement all issues sequentially
    - Right pane: dependency setup followed by an interactive shell

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
        created_at_utc = [DateTime]::UtcNow.ToString('o')
    }
    $issueMetadataJson = $issueMetadata | ConvertTo-Json -Depth 5
    [IO.File]::WriteAllText($issueMetadataPath, $issueMetadataJson, [Text.UTF8Encoding]::new($false))
}

$prompt = @"
Implement GitHub issues $issueReferences sequentially in this dedicated worktree.

For each issue:
1. Read the complete issue and all comments with `gh issue view <number> --comments`.
2. Find the implementation plan and identify every phase before changing code. If the plan is missing or materially unclear, ask me before implementing that issue.
3. Read and follow all applicable repository instructions, including AGENTS.md files.
4. Implement every phase, following existing project patterns. Keep unrelated changes untouched.
5. Run the most relevant focused tests and checks, then inspect the final diff.
6. Commit that issue separately with a message beginning `Fix #<number>:`.
7. Post a concise completion comment to the issue with the phases completed, tests run, changed files, branch $branchName, and commit hash. Identify it as generated by Codex.

Continue through all requested issues unless blocked. Do not push, merge, remove the worktree, or modify files in the original checkout. Preserve any pre-existing changes if this is a resumed worktree. At the end, summarize each issue's status and commit.
"@

$promptBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($prompt))
$quotedWorktree = Quote-PowerShellLiteral $worktreePath

$codexScript = @"
`$prompt = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$promptBase64'))
& codex -C $quotedWorktree --yolo `$prompt
"@
$encodedCodexScript = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($codexScript))

$setupScript = @"
Set-Location $quotedWorktree
Write-Host 'Worktree ready: $worktreePath' -ForegroundColor Green
Write-Host 'Branch: $branchName' -ForegroundColor Green

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
"@
$encodedSetupScript = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($setupScript))

Write-Host "Launching Windows Terminal tab: $tabTitle" -ForegroundColor Cyan
Write-Host "  Worktree: $worktreePath" -ForegroundColor Gray
Write-Host "  Branch:   $branchName" -ForegroundColor Gray
Write-Host "  Base:     $baseBranch" -ForegroundColor Gray
Write-Host "  Issues:   $issueList" -ForegroundColor Gray
Write-Host "  Left:     Codex (interactive, --yolo)" -ForegroundColor Gray
Write-Host "  Right:    dependency setup shell" -ForegroundColor Gray
Write-Host "  Review:   kereview $firstIssue" -ForegroundColor Gray
Write-Host "  Close:    keclose $($allIssues -join ' ')" -ForegroundColor Gray

wt -w 0 new-tab --title $tabTitle --suppressApplicationTitle -d $worktreePath -- powershell -NoExit -EncodedCommand $encodedCodexScript `; split-pane -V --suppressApplicationTitle -d $worktreePath -- powershell -NoExit -EncodedCommand $encodedSetupScript
