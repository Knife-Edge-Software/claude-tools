#!/usr/bin/env node
// Knife Edge Claude Tools - Setup Script (Cross-platform)
// Configures Claude Code with LSP support for Rust, TypeScript, and C++

const fs = require('fs');
const path = require('path');

console.log('Knife Edge Claude Tools Setup');
console.log('==============================\n');

const homeDir = process.env.HOME || process.env.USERPROFILE;
const claudeDir = path.join(homeDir, '.claude');
const settingsPath = path.join(claudeDir, 'settings.json');

const plugins = [
    'rust-analyzer-lsp@claude-plugins-official',
    'typescript-lsp@claude-plugins-official',
    'clangd-lsp@claude-plugins-official',
    'context7@claude-plugins-official'
];

// Create .claude directory if needed
if (!fs.existsSync(claudeDir)) {
    console.log('Creating ~/.claude directory...');
    fs.mkdirSync(claudeDir, { recursive: true });
}

// Load or create settings
let settings = {};
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

// Add plugins
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

console.log(`\nPlugins enabled: ${added} new, ${existing} already configured\n`);
plugins.forEach(p => console.log(`  [+] ${p.split('@')[0]}`));

console.log('\nSetup complete!\n');
console.log('Next steps:');
console.log('  1. Install language servers (if not already installed):');
console.log('     - Rust:       rustup component add rust-analyzer');
console.log('     - TypeScript: npm install -g typescript-language-server typescript');
console.log('     - C++:        Install clangd (via LLVM or Visual Studio)');
console.log('');
console.log('  2. Restart Claude Code for changes to take effect');
console.log('');
