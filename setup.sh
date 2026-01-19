#!/bin/bash
# Knife Edge Claude Tools - Setup Script
# Configures Claude Code with LSP support and the KE plugin marketplace

set -e

echo "Knife Edge Claude Tools Setup"
echo "=============================="
echo ""

# Use Node.js to safely modify JSON (available on all KE dev machines)
if ! command -v node &> /dev/null; then
    echo "Error: Node.js is required but not installed."
    exit 1
fi

node "$(dirname "$0")/setup.js"
