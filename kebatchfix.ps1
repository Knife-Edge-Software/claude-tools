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
if (-not (Test-Path ".git")) {
    Write-Error "Must be run from a git repository root"
    exit 1
}

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
$repoName = Split-Path -Leaf (Get-Location)
$parentDir = Split-Path (Get-Location)
$worktreePath = Join-Path $parentDir "$repoName-issue-$firstIssue"
$tabTitle = "#$firstIssue"
$currentDir = (Get-Location).Path

# Build wait script for right pane (base64 encoded to avoid escaping issues)
$waitScript = @"
Write-Host 'Waiting for worktree: $worktreePath' -ForegroundColor Cyan
while (-not (Test-Path '$worktreePath')) { Start-Sleep -Seconds 2 }
Write-Host 'Worktree found!' -ForegroundColor Green
Set-Location '$worktreePath'

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

Write-Host "Launching Windows Terminal tab: $tabTitle" -ForegroundColor Cyan
Write-Host "  Left pane:  claude /ke:branchfix $issueList" -ForegroundColor Gray
Write-Host "  Right pane: shell -> $worktreePath" -ForegroundColor Gray

# Launch Windows Terminal
# -w 0: new tab in most recent window
# --title: set tab title
# First command runs claude interactively
# split-pane -V: vertical split (right pane)
# Using -EncodedCommand to avoid semicolon parsing issues with wt
wt -w 0 new-tab --title "$tabTitle" --suppressApplicationTitle -d "$currentDir" -- claude --dangerously-skip-permissions "/ke:branchfix $issueList" `; split-pane -V --suppressApplicationTitle -d "$currentDir" -- powershell -NoExit -EncodedCommand $encodedScript
