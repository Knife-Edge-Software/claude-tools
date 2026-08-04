Set-StrictMode -Version Latest

function Assert-AgentToolCommand {
    param([Parameter(Mandatory)][string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found on PATH."
    }
}

function Resolve-AgentToolGitPath {
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$GitPath
    )

    if ([IO.Path]::IsPathRooted($GitPath)) {
        return [IO.Path]::GetFullPath($GitPath)
    }

    return [IO.Path]::GetFullPath((Join-Path $RepositoryRoot $GitPath))
}

function ConvertTo-AgentToolIssueNumbers {
    param([Parameter(Mandatory)][string[]]$Arguments)

    $numbers = [Collections.Generic.List[string]]::new()
    foreach ($argument in $Arguments) {
        foreach ($candidate in ($argument -split ',')) {
            $number = $candidate.Trim().TrimStart('#')
            if (-not $number) {
                continue
            }
            if ($number -notmatch '^\d+$') {
                throw "Invalid issue number: $candidate"
            }
            $numbers.Add($number)
        }
    }

    if ($numbers.Count -eq 0) {
        throw "No issue numbers were provided."
    }

    return $numbers.ToArray()
}

function Get-AgentToolRepositoryContext {
    param([switch]$RequirePrimary)

    Assert-AgentToolCommand git

    $rootOutput = & git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $rootOutput) {
        throw "Run this command from inside the original Git checkout."
    }
    $currentRoot = [IO.Path]::GetFullPath(($rootOutput | Select-Object -First 1).Trim())

    $worktreeOutput = @(& git -C $currentRoot worktree list --porcelain)
    if ($LASTEXITCODE -ne 0 -or $worktreeOutput.Count -eq 0) {
        throw "Unable to inspect Git worktrees."
    }

    $worktrees = [Collections.Generic.List[object]]::new()
    $entry = $null
    foreach ($line in $worktreeOutput) {
        if ($line -like 'worktree *') {
            if ($null -ne $entry) {
                $worktrees.Add([pscustomobject]$entry)
            }
            $entry = [ordered]@{
                Path = [IO.Path]::GetFullPath($line.Substring(9))
                Head = $null
                Branch = $null
            }
        }
        elseif ($null -ne $entry -and $line -like 'HEAD *') {
            $entry.Head = $line.Substring(5)
        }
        elseif ($null -ne $entry -and $line -like 'branch refs/heads/*') {
            $entry.Branch = $line.Substring(18)
        }
    }
    if ($null -ne $entry) {
        $worktrees.Add([pscustomobject]$entry)
    }

    if ($worktrees.Count -eq 0) {
        throw "Git returned no usable worktree records."
    }

    $primaryRoot = $worktrees[0].Path
    $isPrimary = $currentRoot.Equals($primaryRoot, [StringComparison]::OrdinalIgnoreCase)
    if ($RequirePrimary -and -not $isPrimary) {
        throw "Run this command from the original checkout at '$primaryRoot', not from linked worktree '$currentRoot'."
    }

    $currentWorktree = @($worktrees | Where-Object {
        $_.Path.Equals($currentRoot, [StringComparison]::OrdinalIgnoreCase)
    } | Select-Object -First 1)
    if ($currentWorktree.Count -eq 0) {
        throw "Current checkout '$currentRoot' was not found in 'git worktree list'."
    }

    $commonDirOutput = (& git -C $primaryRoot rev-parse --git-common-dir).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $commonDirOutput) {
        throw "Unable to resolve the shared Git metadata directory."
    }

    return [pscustomobject]@{
        Root = $primaryRoot
        CurrentRoot = $currentRoot
        CurrentWorktree = $currentWorktree[0]
        IsPrimary = $isPrimary
        CommonGitDir = Resolve-AgentToolGitPath -RepositoryRoot $primaryRoot -GitPath $commonDirOutput
        Worktrees = $worktrees.ToArray()
    }
}

function Get-AgentToolIssueWorktree {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$Issue
    )

    $branchName = "issue-$Issue"
    $matches = @($Context.Worktrees | Where-Object { $_.Branch -eq $branchName })
    if ($matches.Count -eq 0) {
        throw "No registered worktree is checked out on branch '$branchName'."
    }
    if ($matches.Count -gt 1) {
        throw "Multiple worktrees unexpectedly matched branch '$branchName'."
    }
    if (-not (Test-Path -LiteralPath $matches[0].Path)) {
        throw "Registered worktree path does not exist: $($matches[0].Path)"
    }

    return $matches[0]
}

function Get-AgentToolStateDirectory {
    param([Parameter(Mandatory)]$Context)

    return Join-Path $Context.CommonGitDir 'agenttools'
}

function Get-AgentToolIssueMetadataPath {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$Issue
    )

    return Join-Path (Join-Path (Get-AgentToolStateDirectory $Context) 'issues') "issue-$Issue.json"
}

function Get-AgentToolReviewStatePath {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$Issue
    )

    return Join-Path (Join-Path (Get-AgentToolStateDirectory $Context) 'reviews') "issue-$Issue.json"
}

function Get-AgentToolIssueMetadata {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$Issue
    )

    $path = Get-AgentToolIssueMetadataPath -Context $Context -Issue $Issue
    if (-not (Test-Path -LiteralPath $path)) {
        return $null
    }

    try {
        return Get-Content -Raw -LiteralPath $path | ConvertFrom-Json
    }
    catch {
        throw "Issue metadata is unreadable: $path"
    }
}

function Get-AgentToolCurrentIssueNumber {
    param([Parameter(Mandatory)]$Context)

    $branch = $Context.CurrentWorktree.Branch
    if (-not $branch -or $branch -notmatch '^issue-(\d+)$') {
        throw "Current checkout is not on an issue branch. Supply an issue number explicitly."
    }

    return $Matches[1]
}

function Get-AgentToolLockDirectory {
    param(
        [Parameter(Mandatory)]$Context,
        [Parameter(Mandatory)][string]$Issue
    )

    return Join-Path (Join-Path (Get-AgentToolStateDirectory $Context) 'locks') "issue-$Issue"
}

function Write-AgentToolJson {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Value
    )

    $directory = Split-Path -Parent $Path
    [IO.Directory]::CreateDirectory($directory) | Out-Null
    $json = $Value | ConvertTo-Json -Depth 8
    [IO.File]::WriteAllText($Path, $json, [Text.UTF8Encoding]::new($false))
}
