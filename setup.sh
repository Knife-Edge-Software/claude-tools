#!/bin/bash
# Knife Edge Claude Tools - Setup Script
# Configures Claude Code with LSP support for Rust, TypeScript, and C++

set -e

SETTINGS_FILE="$HOME/.claude/settings.json"

echo "Knife Edge Claude Tools Setup"
echo "=============================="
echo ""

# Check if Claude directory exists
if [ ! -d "$HOME/.claude" ]; then
    echo "Creating ~/.claude directory..."
    mkdir -p "$HOME/.claude"
fi

# LSP plugins to enable
PLUGINS=(
    "rust-analyzer-lsp@claude-plugins-official"
    "typescript-lsp@claude-plugins-official"
    "clangd-lsp@claude-plugins-official"
    "context7@claude-plugins-official"
)

# Use Node.js to safely modify JSON (available on all KE dev machines)
if ! command -v node &> /dev/null; then
    echo "Error: Node.js is required but not installed."
    exit 1
fi

node << 'NODESCRIPT'
const fs = require('fs');
const path = require('path');

const settingsPath = path.join(process.env.HOME || process.env.USERPROFILE, '.claude', 'settings.json');
const plugins = [
    'rust-analyzer-lsp@claude-plugins-official',
    'typescript-lsp@claude-plugins-official',
    'clangd-lsp@claude-plugins-official',
    'context7@claude-plugins-official'
];

let settings = {};

// Load existing settings if present
if (fs.existsSync(settingsPath)) {
    try {
        settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
        console.log('Loaded existing settings.json');
    } catch (e) {
        console.log('Warning: Could not parse existing settings.json, starting fresh');
        settings = {};
    }
}

// Ensure enabledPlugins exists
if (!settings.enabledPlugins) {
    settings.enabledPlugins = {};
}

// Add each plugin
let added = 0;
let existing = 0;
for (const plugin of plugins) {
    if (settings.enabledPlugins[plugin]) {
        existing++;
    } else {
        settings.enabledPlugins[plugin] = true;
        added++;
    }
}

// Write settings
fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + '\n');

console.log('');
console.log(`Plugins enabled: ${added} new, ${existing} already configured`);
console.log('');
plugins.forEach(p => console.log(`  ✓ ${p.split('@')[0]}`));
NODESCRIPT

echo ""
echo "Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Install language servers (if not already installed):"
echo "     - Rust:       rustup component add rust-analyzer"
echo "     - TypeScript: npm install -g typescript-language-server typescript"
echo "     - C++:        Install clangd (via LLVM, Visual Studio, or package manager)"
echo ""
echo "  2. Restart Claude Code for changes to take effect"
echo ""
