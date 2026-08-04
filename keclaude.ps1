#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Runs Claude CLI with any command and outputs the result.

.DESCRIPTION
    Pass any command/prompt to Claude CLI non-interactively.
    All arguments are joined and passed as the prompt.

.EXAMPLE
    keclaude /ke:plan --milestone foo
    keclaude /ke:fix 123
    keclaude "explain this function"
#>

$ErrorActionPreference = "Stop"

# Join all arguments into a single prompt
$prompt = $args -join ' '

if (-not $prompt) {
    Write-Error "Usage: keclaude <command> [args...]"
    Write-Error "Example: keclaude /ke:plan --milestone foo"
    exit 1
}

# Verify Claude CLI is installed
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Error "Claude CLI not found. Please install it first."
    exit 1
}

# Run Claude CLI with --print for non-interactive output
try {
    & claude -p $prompt --print --dangerously-skip-permissions
    $exitCode = $LASTEXITCODE
}
catch {
    Write-Error "Claude CLI execution failed: $_"
    exit 1
}

exit $exitCode
