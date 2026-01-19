# Knife Edge Claude Tools

A Claude Code plugin for the Knife Edge Software team providing issue management commands.

## Installation

### Quick Install (Recommended)

Run these commands in Claude Code:

```
/plugin marketplace add Knife-Edge-Software/claude-tools
/plugin install ke@knife-edge-software-claude-tools
```

That's it! The `/ke:plan`, `/ke:fix`, and other commands are now available.

### Manual Install via Settings

If you prefer to edit settings files directly:

**Step 1:** Add the marketplace to your settings file:

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
      }
    }
  }
}
```

**Step 3:** Restart Claude Code.

### Development / Testing

For local development and testing:

```bash
# Clone the repo
git clone https://github.com/Knife-Edge-Software/claude-tools.git

# Run Claude Code with the plugin (note: plugin is in plugins/ke/ subdirectory)
claude --plugin-dir /path/to/claude-tools/plugins/ke
```

## Commands

All commands use the `ke:` namespace prefix.

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

```bash
/ke:plan 42           # Plan issue #42
/ke:plan 42 43 44     # Plan multiple issues
/ke:plan              # Shows unplanned issues to choose from
```

#### `/ke:branchfix`
Implement issues in a dedicated git worktree, keeping main directory clean.

```bash
/ke:branchfix 42          # Work on issue #42 in worktree
/ke:branchfix 42 43 44    # Work on multiple issues in same worktree
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
