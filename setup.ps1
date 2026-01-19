# Knife Edge Claude Tools - Setup Script (PowerShell)
# Configures Claude Code with LSP support and the KE plugin marketplace

$ErrorActionPreference = "Stop"

Write-Host "Knife Edge Claude Tools Setup" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host ""

$settingsPath = Join-Path $env:USERPROFILE ".claude\settings.json"
$claudeDir = Join-Path $env:USERPROFILE ".claude"

# Create .claude directory if needed
if (-not (Test-Path $claudeDir)) {
    Write-Host "Creating ~/.claude directory..."
    New-Item -ItemType Directory -Path $claudeDir | Out-Null
}

# Plugins to enable
$plugins = @{
    "rust-analyzer-lsp@claude-plugins-official" = $true
    "typescript-lsp@claude-plugins-official" = $true
    "clangd-lsp@claude-plugins-official" = $true
    "context7@claude-plugins-official" = $true
}

# Load or create settings
$settings = @{}
if (Test-Path $settingsPath) {
    try {
        $content = Get-Content $settingsPath -Raw -Encoding UTF8
        if ($content) {
            # Remove BOM if present
            $content = $content -replace '^\xEF\xBB\xBF', ''
            $settings = $content | ConvertFrom-Json -AsHashtable
        }
        Write-Host "Loaded existing settings.json"
    } catch {
        Write-Host "Warning: Could not parse existing settings.json, starting fresh" -ForegroundColor Yellow
        $settings = @{}
    }
}

# Ensure enabledPlugins exists
if (-not $settings.ContainsKey("enabledPlugins")) {
    $settings["enabledPlugins"] = @{}
}

# Add plugins
$added = 0
$existing = 0
foreach ($plugin in $plugins.Keys) {
    if ($settings["enabledPlugins"].ContainsKey($plugin)) {
        $existing++
    } else {
        $settings["enabledPlugins"][$plugin] = $true
        $added++
    }
}

# Write settings WITHOUT BOM
$json = $settings | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($settingsPath, $json, [System.Text.UTF8Encoding]::new($false))

Write-Host ""
Write-Host "Plugins enabled: $added new, $existing already configured"
Write-Host ""
foreach ($plugin in $plugins.Keys) {
    $name = $plugin.Split("@")[0]
    Write-Host "  [+] $name" -ForegroundColor Green
}

Write-Host ""
Write-Host "Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Install language servers (if not already installed):"
Write-Host "     - Rust:       rustup component add rust-analyzer"
Write-Host "     - TypeScript: npm install -g typescript-language-server typescript"
Write-Host "     - C++:        Install clangd (via LLVM or Visual Studio)"
Write-Host ""
Write-Host "  2. Restart Claude Code for changes to take effect"
Write-Host ""
Write-Host "  3. For KE commands, start Claude with:"
Write-Host "     claude --plugin-dir `$HOME\claude-tools\plugins\ke"
Write-Host ""
