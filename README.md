# Knife Edge Claude Tools

A Claude Code plugin for the Knife Edge Software team providing issue management commands.

## Installation

Run these commands in Claude Code:

```
/plugin marketplace add Knife-Edge-Software/claude-tools
/plugin install ke@knife-edge-software-claude-tools
```

Then enable auto-updates so you always have the latest version:

1. Run `/plugin` in Claude Code
2. Go to **Marketplaces** tab
3. Find `knife-edge-software-claude-tools`
4. Toggle **auto-update** on

That's it! The `/ke:plan`, `/ke:fix`, and other commands are now available.

## Commands

All commands use the `ke:` namespace prefix.

### Issue Management

| Command | Description |
|---------|-------------|
| `/ke:plan [issue]` | Create an implementation plan for a GitHub issue |
| `/ke:map [issues]` | Analyze dependencies and plan execution order |
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

```bash
/ke:plan 42           # Plan issue #42
/ke:plan 42 43 44     # Plan multiple issues
/ke:plan              # Shows unplanned issues to choose from
```

#### `/ke:map`
Analyze dependencies across issues and output an execution plan with parallel tracks.

```bash
/ke:map               # Analyze all open issues
/ke:map 42 45 47 50   # Analyze specific issues only
/ke:map --label bug   # Analyze only issues with "bug" label
```

Detects dependencies based on file overlap, writes them to issues, and outputs:
- Execution commands grouped by parallel track
- Mermaid dependency graph
- List of blocked/unplanned issues

#### `/ke:branchfix`
Implement issues in a dedicated git worktree, keeping main directory clean.

```bash
/ke:branchfix 42              # Work on issue #42 in worktree
/ke:branchfix 42 43 44        # Multiple issues in same worktree (sequential)
/ke:branchfix 42 43 44 --split  # Separate worktree per issue (for separate PRs)
```

#### `/ke:close`
Finalize work by merging worktree (if applicable), pushing, and closing the issue.

```bash
/ke:close 42
```

#### `/ke:create`
Create new issues with optional milestone and assignee.

```bash
/ke:create Add dark mode toggle
/ke:create Fix login bug --assignee @me
/ke:create New feature --milestone v2.0 --assignee johndoe
```

#### `/ke:pr`
Create a pull request linking to an issue.

```bash
/ke:pr 42
/ke:pr 42 --reviewer johndoe --draft
```

## Workflows

### Simple
For quick fixes without worktrees:
1. `/ke:plan 42` - Create implementation plan
2. `/ke:fix 42` - Implement
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

### Parallel
For working through multiple issues efficiently:
1. `/ke:plan 42 43 44 45` - Plan all issues
2. `/ke:map` - Analyze dependencies and get execution plan
3. Run each track in a separate terminal (commands provided by map)
4. `/ke:close` each issue as tracks complete

## Development / Testing

For local development and testing:

```bash
# Clone the repo
git clone https://github.com/Knife-Edge-Software/claude-tools.git

# Run Claude Code with the plugin (note: plugin is in plugins/ke/ subdirectory)
claude --plugin-dir /path/to/claude-tools/plugins/ke
```

## Requirements

- [Claude Code](https://claude.ai/download) installed
- [GitHub CLI](https://cli.github.com/) (`gh`) installed and authenticated (`gh auth login`)
- Git 2.x+

## Contributing

1. Clone the repo
2. Make changes to commands in `plugins/ke/commands/`
3. Test with `claude --plugin-dir ./plugins/ke`
4. Submit a PR

## License

MIT

---

## Advanced

### Manual Installation

If you prefer to edit settings files directly:

**Step 1:** Choose your settings file:

| Scope | File Location |
|-------|---------------|
| User (all projects) | `~/.claude/settings.json` |
| Project (shared with team) | `.claude/settings.json` |
| Local (just you, gitignored) | `.claude/settings.local.json` |

**Step 2:** Add this configuration:

```json
{
  "enabledPlugins": {
    "ke@knife-edge-software-claude-tools": true
  },
  "extraKnownMarketplaces": {
    "knife-edge-software-claude-tools": {
      "source": {
        "source": "github",
        "repo": "Knife-Edge-Software/claude-tools"
      },
      "autoUpdate": true
    }
  }
}
```

**Step 3:** Restart Claude Code.

### Manual Updates

If you don't have auto-update enabled:

```bash
# Update via CLI
claude plugin update ke@knife-edge-software-claude-tools

# Or refresh marketplace
/plugin marketplace update knife-edge-software-claude-tools
```

