#!/usr/bin/env node
// Knife Edge Claude Tools - Setup Script (Cross-platform)
// Configures Claude Code with LSP support and the KE plugin marketplace

const fs = require('fs');
const path = require('path');

console.log('Knife Edge Claude Tools Setup');
console.log('==============================\n');

const homeDir = process.env.HOME || process.env.USERPROFILE;
const claudeDir = path.join(homeDir, '.claude');
const settingsPath = path.join(claudeDir, 'settings.json');

const plugins = {
    'rust-analyzer-lsp@claude-plugins-official': true,
    'typescript-lsp@claude-plugins-official': true,
    'clangd-lsp@claude-plugins-official': true,
    'context7@claude-plugins-official': true,
    'ke@knife-edge': true
};

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

// Ensure extraKnownMarketplaces exists and add knife-edge
if (!settings.extraKnownMarketplaces) {
    settings.extraKnownMarketplaces = {};
}
settings.extraKnownMarketplaces['knife-edge'] = 'https://github.com/Knife-Edge-Software/claude-tools';

// Add plugins
let added = 0;
let existing = 0;
for (const [plugin, enabled] of Object.entries(plugins)) {
    if (settings.enabledPlugins[plugin]) {
        existing++;
    } else {
        settings.enabledPlugins[plugin] = enabled;
        added++;
    }
}

// Write settings
fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + '\n');

console.log('\nMarketplace configured: knife-edge -> GitHub\n');
console.log(`Plugins enabled: ${added} new, ${existing} already configured\n`);
Object.keys(plugins).forEach(p => console.log(`  [+] ${p.split('@')[0]}`));

console.log('\nSetup complete!\n');
console.log('Next steps:');
console.log('  1. Install language servers (if not already installed):');
console.log('     - Rust:       rustup component add rust-analyzer');
console.log('     - TypeScript: npm install -g typescript-language-server typescript');
console.log('     - C++:        Install clangd (via LLVM or Visual Studio)');
console.log('');
console.log('  2. Restart Claude Code for changes to take effect');
console.log('');
console.log('  3. Run /ke:status to verify the plugin is loaded');
console.log('');
