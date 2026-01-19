# Knife Edge Claude Tools

A Claude Code plugin marketplace for the Knife Edge Software team providing issue management commands and development environment configuration.

## Installation

**Option 1: Download and run setup script (recommended)**

```powershell
# Download setup script
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Knife-Edge-Software/claude-tools/main/setup.ps1" -OutFile "$env:TEMP\ke-setup.ps1"

# Run it
& "$env:TEMP\ke-setup.ps1"

# Restart Claude Code
```

**Option 2: Clone and run locally**

```powershell
# Clone the repo
git clone https://github.com/Knife-Edge-Software/claude-tools.git $HOME\.claude\ke-tools

# Run setup
& $HOME\.claude\ke-tools\setup.ps1

# Restart Claude Code
```

## What the Setup Script Does

1. **Registers the knife-edge marketplace** in Claude Code settings
2. **Enables these plugins:**
   - `ke@knife-edge` - Issue management commands
   - `rust-analyzer-lsp` - Rust language support
   - `typescript-lsp` - TypeScript/JavaScript support
   - `clangd-lsp` - C/C++ support
   - `context7` - Library documentation

### Prerequisites

The language servers must be installed on your system:

```powershell
# Rust (via rustup)
rustup component add rust-analyzer

# TypeScript
npm install -g typescript-language-server typescript

# C++ - Install one of:
#   - Visual Studio with C++ workload (includes clangd)
#   - LLVM: https://releases.llvm.org/ (includes clangd)
#   - winget install LLVM.LLVM
```

## Commands

All commands use the `/ke:` prefix.

### Issue Management

| Command | Description |
|---------|-------------|
| `/ke:plan [issue]` | Create an implementation plan for a GitHub issue |
| `/ke:fix [issue]` | Implement a GitHub issue (no worktree) |
| `/ke:branchfix [issue]` | Implement a GitHub issue in a dedicated worktree |
| `/ke:step [issue]` | Implement the next step from an issue plan |
| `/ke:close [issue]` | Commit, push, and close a GitHub issue |
| `/ke:status` | Show all issue work in progress |
| `/ke:create <desc>` | Create a new GitHub issue |
| `/ke:pr [issue]` | Create a pull request for an issue |
| `/ke:comment [issue]` | Add a comment to a GitHub issue |
| `/ke:assign [issue]` | Assign users to a GitHub issue |
| `/ke:abort [issue]` | Abandon work on an issue (cleanup worktree/branch) |

### Command Details

#### `/ke:plan`
Review a GitHub issue and create a detailed implementation plan posted as a comment.

```
/ke:plan 42           # Plan issue #42
/ke:plan 42 43 44     # Plan multiple issues
/ke:plan              # Shows unplanned issues to choose from
```

#### `/ke:branchfix`
Implement issues in a dedicated git worktree, keeping main directory clean.

```
/ke:branchfix 42          # Work on issue #42 in worktree
/ke:branchfix 42 43 44    # Work on multiple issues in same worktree
```

#### `/ke:close`
Finalize work by merging worktree (if applicable), pushing, and closing the issue.

```
/ke:close 42
```

#### `/ke:create`
Create new issues with optional milestone and assignee.

```
/ke:create Add dark mode toggle
/ke:create Fix login bug --assignee @me
/ke:create New feature --milestone v2.0 --assignee johndoe
```

#### `/ke:pr`
Create a pull request linking to an issue.

```
/ke:pr 42
/ke:pr 42 --reviewer johndoe --draft
```

## Workflows

### Simple
For quick fixes without worktrees:
1. `/ke:plan 42` - Create implementation plan
2. `/ke:fix 42` - Implement the solution
3. `/ke:close 42` - Commit, push, and close

### Typical
For most work, using isolated worktrees:
1. `/ke:plan 42` - Create implementation plan
2. `/ke:branchfix 42` - Create worktree and implement
3. **Review** - Claude asks for review before finishing
4. `/ke:close 42` - Merge worktree, push, and close

### Full
When you need a formal PR review:
1. `/ke:plan 42` - Create implementation plan
2. `/ke:branchfix 42` - Create worktree and implement
3. **Review** - Claude asks for review before finishing
4. `/ke:pr 42` - Push and create pull request
5. `/ke:close 42` - Merge and cleanup (after PR approved)

## Requirements

- [Claude Code](https://claude.ai/code) installed
- [GitHub CLI](https://cli.github.com/) (`gh`) authenticated
- Git 2.x+
- Language servers (see Prerequisites)

## Contributing

1. Clone the repo
2. Make changes to plugins in `plugins/ke/`
3. Test with `claude --plugin-dir ./plugins/ke`
4. Submit a PR

## License

MIT
