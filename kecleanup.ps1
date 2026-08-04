#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Removes finalized issue worktrees after their terminal panes have closed.

.DESCRIPTION
    With no issue number, safely cleans every finalized, unlocked, clean, fully
    merged worktree recorded in this repository's agenttools metadata.

.EXAMPLE
    kecleanup
    kecleanup 42
#>

param(
    [Parameter(Position=0)]
    [string]$Issue,

    [Parameter()]
    [switch]$Quiet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'agenttools-common.ps1')

$context = Get-AgentToolRepositoryContext
$issuesDirectory = Join-Path (Get-AgentToolStateDirectory $context) 'issues'
if (-not (Test-Path -LiteralPath $issuesDirectory)) {
    if (-not $Quiet) { Write-Host 'No agenttools issue metadata was found.' -ForegroundColor Gray }
    exit 0
}

$metadataPaths = if ($Issue) {
    $number = @(ConvertTo-AgentToolIssueNumbers @($Issue))[0]
    @(Get-AgentToolIssueMetadataPath -Context $context -Issue $number)
}
else {
    @(Get-ChildItem -LiteralPath $issuesDirectory -Filter 'issue-*.json' -File | Select-Object -ExpandProperty FullName)
}

$cleaned = 0
$skipped = 0
foreach ($metadataPath in $metadataPaths) {
    if (-not (Test-Path -LiteralPath $metadataPath)) {
        if (-not $Quiet) { Write-Warning "Metadata not found: $metadataPath" }
        $skipped++
        continue
    }

    try {
        $metadata = Get-Content -Raw -LiteralPath $metadataPath | ConvertFrom-Json
    }
    catch {
        if (-not $Quiet) { Write-Warning "Unreadable metadata: $metadataPath" }
        $skipped++
        continue
    }

    $statusProperty = $metadata.PSObject.Properties['status']
    if (-not $statusProperty -or $statusProperty.Value -ne 'finalized') {
        continue
    }

    $branchName = [string]$metadata.branch
    $worktreePath = [IO.Path]::GetFullPath([string]$metadata.worktree)
    $baseBranch = [string]$metadata.base_branch
    $firstIssue = [string](@($metadata.issues)[0])

    if ($context.CurrentRoot.Equals($worktreePath, [StringComparison]::OrdinalIgnoreCase)) {
        if (-not $Quiet) { Write-Warning "Skipping issue #$firstIssue because this shell is inside its worktree." }
        $skipped++
        continue
    }

    $lockDirectory = Get-AgentToolLockDirectory -Context $context -Issue $firstIssue
    $locked = $false
    if (Test-Path -LiteralPath $lockDirectory) {
        foreach ($lockFile in @(Get-ChildItem -LiteralPath $lockDirectory -Filter '*.lock' -File)) {
            try {
                $stream = [IO.File]::Open($lockFile.FullName, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
                $stream.Dispose()
            }
            catch [IO.IOException] {
                $locked = $true
                break
            }
        }
    }
    if ($locked) {
        if (-not $Quiet) { Write-Warning "Skipping issue #$firstIssue because one or more terminal panes are still open." }
        $skipped++
        continue
    }

    $registered = @($context.Worktrees | Where-Object {
        $_.Path.Equals($worktreePath, [StringComparison]::OrdinalIgnoreCase)
    })
    if ($registered.Count -gt 0) {
        $dirty = @(& git -C $worktreePath status --porcelain)
        if ($LASTEXITCODE -ne 0 -or $dirty.Count -gt 0) {
            if (-not $Quiet) { Write-Warning "Skipping issue #$firstIssue because its worktree is not clean." }
            $skipped++
            continue
        }
    }

    & git -C $context.Root merge-base --is-ancestor $branchName $baseBranch
    if ($LASTEXITCODE -ne 0) {
        if (-not $Quiet) { Write-Warning "Skipping issue #$firstIssue because '$branchName' is not fully merged into '$baseBranch'." }
        $skipped++
        continue
    }

    if ($registered.Count -gt 0) {
        & git -C $context.Root worktree remove $worktreePath
        if ($LASTEXITCODE -ne 0) {
            if (-not $Quiet) { Write-Warning "Could not remove worktree for issue #$firstIssue; it may still be in use." }
            $skipped++
            continue
        }
    }

    $branchExists = @(& git -C $context.Root branch --list --format='%(refname:short)' -- $branchName) -contains $branchName
    if ($branchExists) {
        & git -C $context.Root branch -d $branchName
        if ($LASTEXITCODE -ne 0) {
            if (-not $Quiet) { Write-Warning "Removed the worktree but could not delete '$branchName'." }
            $skipped++
            continue
        }
    }

    $metadata | Add-Member -NotePropertyName status -NotePropertyValue 'cleaned' -Force
    $metadata | Add-Member -NotePropertyName cleaned_at_utc -NotePropertyValue ([DateTime]::UtcNow.ToString('o')) -Force
    Write-AgentToolJson -Path $metadataPath -Value $metadata
    if (Test-Path -LiteralPath $lockDirectory) {
        [IO.Directory]::Delete($lockDirectory, $true)
    }
    if (-not $Quiet) { Write-Host "Cleaned issue #$firstIssue worktree and branch." -ForegroundColor Green }
    $cleaned++
}

if (-not $Quiet) {
    Write-Host "Cleanup complete: $cleaned cleaned, $skipped skipped." -ForegroundColor Cyan
}
