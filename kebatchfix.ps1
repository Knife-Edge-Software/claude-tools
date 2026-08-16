#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Opens a Windows Terminal tab with Claude running /ke:branchfix and a shell pane.

.DESCRIPTION
    Creates a split-pane Windows Terminal tab:
    - Left pane: Claude running /ke:branchfix interactively
    - Right pane: Shell that waits for worktree creation, then cds into it

.PARAMETER Issues
    Issue numbers (space or comma-separated)

.EXAMPLE
    kebatchfix 209 210
    kebatchfix 1,2,3
#>

param(
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$Issues
)

$ErrorActionPreference = "Stop"

# Validate we're in a git repo
$repoRootOutput = & git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0 -or -not $repoRootOutput) {
    Write-Error "Must be run from inside a git repository"
    exit 1
}
$repoRoot = [IO.Path]::GetFullPath(($repoRootOutput | Select-Object -First 1).Trim())

# Validate we have issues
if (-not $Issues -or $Issues.Count -eq 0) {
    Write-Error "Usage: kebatchfix <issue-numbers>"
    Write-Error "Example: kebatchfix 209 210"
    exit 1
}

# Parse issue numbers (handle both space-separated args and comma-separated)
$allIssues = @()
foreach ($arg in $Issues) {
    $allIssues += ($arg -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}
$issueList = $allIssues -join ' '
$firstIssue = $allIssues[0]

if (-not $firstIssue -or $firstIssue -notmatch '^\d+$') {
    Write-Error "Invalid issue number: $firstIssue"
    exit 1
}

# Compute paths
$repoName = Split-Path -Leaf $repoRoot
$parentDir = Split-Path -Parent $repoRoot
$branchName = "issue-$firstIssue"
$expectedWorktree = Join-Path $parentDir "$repoName-issue-$firstIssue"
$tabTitle = "#$firstIssue"
$currentDir = $repoRoot

# Build wait script for right pane (base64 encoded to avoid escaping issues)
#
# The worktree is created by Claude, so its location cannot be assumed. Ask Git
# where the branch was actually checked out instead of polling a guessed path:
# a worktree placed anywhere (for example under .claude/worktrees/) is still
# found, and the pane reports the discrepancy rather than waiting forever.
$waitScript = @"
`$repoRoot = '$repoRoot'
`$branchName = '$branchName'
`$expectedWorktree = '$expectedWorktree'

Write-Host "Waiting for a worktree on branch `$branchName..." -ForegroundColor Cyan
Write-Host "Expected location: `$expectedWorktree" -ForegroundColor DarkGray

`$worktreePath = `$null
while (-not `$worktreePath) {
    `$candidate = `$null
    foreach (`$line in @(& git -C `$repoRoot worktree list --porcelain 2>`$null)) {
        if (`$line -like 'worktree *') {
            `$candidate = `$line.Substring(9)
        }
        elseif (`$line -eq "branch refs/heads/`$branchName") {
            `$worktreePath = [IO.Path]::GetFullPath(`$candidate)
            break
        }
    }
    if (-not `$worktreePath) { Start-Sleep -Seconds 2 }
}

if (`$worktreePath -ne [IO.Path]::GetFullPath(`$expectedWorktree)) {
    Write-Host "Worktree found at an unexpected location: `$worktreePath" -ForegroundColor Yellow
    Write-Host "Expected a sibling directory: `$expectedWorktree" -ForegroundColor Yellow
}
else {
    Write-Host "Worktree found: `$worktreePath" -ForegroundColor Green
}
Set-Location -LiteralPath `$worktreePath

Write-Host ''
Write-Host 'Running npm install...' -ForegroundColor Cyan
npm install

# Pre-fetch Rust dependencies and do debug build if src-tauri exists
if (Test-Path 'src-tauri') {
    Write-Host ''
    Write-Host 'Fetching Rust dependencies...' -ForegroundColor Cyan
    Push-Location src-tauri
    cargo fetch

    Write-Host ''
    Write-Host 'Running debug build...' -ForegroundColor Cyan
    cargo build
    Pop-Location
}

Write-Host ''
Write-Host 'Ready! Run: npm run rundev' -ForegroundColor Green
"@
$encodedScript = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($waitScript))

# Build claude script for left pane
$claudeScript = @"
& claude --dangerously-skip-permissions '/ke:branchfix $issueList'
"@
$encodedClaudeScript = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($claudeScript))

Write-Host "Launching Windows Terminal tab: $tabTitle" -ForegroundColor Cyan
Write-Host "  Left pane:  claude /ke:branchfix $issueList" -ForegroundColor Gray
Write-Host "  Right pane: shell -> worktree on branch $branchName (expected $expectedWorktree)" -ForegroundColor Gray

# Launch Windows Terminal
# -w 0: new tab in most recent window
# --title: set tab title
# Use encoded script for left pane to avoid quoting issues (cmd /c works around Bun crash)
# split-pane -V: vertical split (right pane)
# Using -EncodedCommand for both panes to avoid escaping issues
wt -w 0 new-tab --title "$tabTitle" --suppressApplicationTitle -d "$currentDir" -- powershell -NoExit -EncodedCommand $encodedClaudeScript `; split-pane -V --suppressApplicationTitle -d "$currentDir" -- powershell -NoExit -EncodedCommand $encodedScript
