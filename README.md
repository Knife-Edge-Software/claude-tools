# Knife Edge Claude Tools

A Claude Code plugin for the Knife Edge Software team providing issue management commands, C++/Rust development support, and flight simulation domain knowledge.

## Installation

```bash
# Clone the plugin to your Claude plugins directory
git clone https://github.com/Knife-Edge-Software/claude-tools.git ~/.claude/plugins/ke

# Run Claude Code with the plugin
claude --plugin-dir ~/.claude/plugins/ke
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

## LSP Support

The plugin configures language servers for:

- **C++**: clangd with background indexing
- **Rust**: rust-analyzer

File extensions mapped:
- `.cpp`, `.hpp`, `.h`, `.cc` → C++
- `.rs` → Rust

## Hooks

Auto-formatting hooks run after file edits:

- **C++/HPP/H files**: `clang-format -i`
- **Rust files**: `cargo fmt`

## Skills

Domain knowledge included:

### Flight Simulation (`skills/flight-sim/`)
- Units and conventions (meters, knots, radians)
- Coordinate systems (ECEF, NED, body)
- Performance targets (FPS, memory budgets)
- Common simulation patterns

### C++ Patterns (`skills/cpp-patterns/`)
- Modern C++ standards (C++17/20)
- Memory management (smart pointers, RAII)
- Error handling patterns
- Threading best practices
- Performance optimization
- Code style guidelines

## Typical Workflow

1. **Plan**: `/ke:plan 42` - Create implementation plan
2. **Start work**: `/ke:branchfix 42` - Create worktree and implement
3. **Review**: Claude asks for review before finishing
4. **Close**: `/ke:close 42` - Merge and cleanup
5. *(Optional)* **Create PR**: `/ke:pr 42` - If you need a formal review

Or for simpler changes without worktrees:
1. `/ke:plan 42`
2. `/ke:fix 42`
3. `/ke:close 42`

## Requirements

- [Claude CLI](https://docs.anthropic.com/claude-code) installed
- [GitHub CLI](https://cli.github.com/) (`gh`) authenticated
- Git 2.x+
- For LSP: `clangd` and/or `rust-analyzer` installed
- For hooks: `clang-format` and/or `cargo`

## Contributing

1. Clone the repo
2. Make changes to commands in `commands/`
3. Test with `claude --plugin-dir ./`
4. Submit a PR

## License

MIT
