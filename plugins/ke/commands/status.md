---
description: Show all issue work in progress
---

# Issue Status

Show the status of all issue work in progress across worktrees and branches.

## Usage

```
/ke:status
```

## Instructions

Display a comprehensive overview of the current working directory and all in-progress issue work.

### Step 0: Show Current Working Directory Status

First, display information about the current working directory:

1. **Current directory path** - the absolute path
2. **Current branch** - which branch is checked out
3. **Git status** - uncommitted changes (staged, unstaged, untracked)
4. **Last commit** - hash and message
5. **Remote status** - ahead/behind origin

Use these commands:
```bash
# Current branch
git branch --show-current

# Last commit
git log -1 --format="%h %s (%cr)"

# Uncommitted changes
git status --short

# Ahead/behind origin
git rev-list --left-right --count HEAD...@{upstream}
```

Display this first in the output:
```markdown
## Current Directory

**Path:** /projects/myapp
**Branch:** main
**Last commit:** abc1234 - "Fix login bug" (2 hours ago)
**Status:** Clean (no uncommitted changes)
```

Or if there are changes:
```markdown
## Current Directory

**Path:** /projects/myapp
**Branch:** feature-xyz
**Last commit:** abc1234 - "WIP feature" (30 minutes ago)
**Uncommitted changes:**
- M  src/app.ts (modified)
- A  src/new-file.ts (staged)
- ?? src/temp.txt (untracked)
**Remote:** 2 commits ahead of origin
```

### Step 1: Find All Issue Worktrees

Run `git worktree list` to find all worktrees. Filter for issue-related worktrees (those with `issue-` in the path or branch name).

### Step 2: For Each Issue Worktree, Gather Info

For each issue worktree, collect:
1. **Worktree path**
2. **Branch name**
3. **Issue number(s)** - extracted from branch name (e.g., `issue-42` → #42)
4. **Last commit** - hash and message
5. **Uncommitted changes** - count of modified/staged files
6. **Behind main** - how many commits behind the main branch
7. **Issue title** - fetch from GitHub if possible

Use these commands:
```bash
# Last commit
git -C <worktree-path> log -1 --format="%h %s"

# Uncommitted changes
git -C <worktree-path> status --porcelain | wc -l

# Commits behind main
git -C <worktree-path> rev-list --count HEAD..origin/main
```

### Step 3: Check for Issue Branches Without Worktrees

Also check for local branches named `issue-*` that don't have active worktrees:
```bash
git branch --list "issue-*"
```

### Step 4: Display Results

Format the output as a table:

```markdown
## Active Issue Worktrees

| Issue | Title | Branch | Location | Last Commit | Uncommitted | Behind Main |
|-------|-------|--------|----------|-------------|-------------|-------------|
| #50 | Edit issue state | issue-50 | ../repo-issue-50 | abc1234 "Add state mutation" | 3 files | 2 commits |
| #58 | Markdown rendering | issue-58 | ../repo-issue-58 | def5678 "Fix marked config" | 0 files | 0 commits |

## Stale Issue Branches (no worktree)

| Branch | Last Commit | Age |
|--------|-------------|-----|
| issue-32 | ghi9012 "WIP sub-issues" | 5 days ago |

## Summary
- **Active worktrees:** 2
- **Stale branches:** 1
- **Total uncommitted changes:** 3 files
```

### Step 5: Provide Recommendations

Based on the status, suggest actions:

- If worktree has uncommitted changes: "Consider committing or stashing changes in issue-50"
- If branch is far behind main: "Consider rebasing issue-58 onto main"
- If stale branches exist: "Consider cleaning up branch issue-32 with `git branch -d issue-32`"
- If no active work: "No issue work in progress. Use `/ke:branchfix <number>` to start."

### Edge Cases

- **No worktrees found:** Report "No active issue worktrees found"
- **Git errors:** Report which worktrees had errors accessing
- **Offline:** Skip GitHub API calls, show "Title unavailable" for issues

### Example Output

```
## Current Directory

**Path:** /projects/IssueSpace
**Branch:** main
**Last commit:** 9f2a3b1 - "Merge PR #49: Add search feature" (1 day ago)
**Status:** Clean

---

## Issue Work Status

### Active Worktrees

| Issue | Title | Branch | Uncommitted | Behind Main |
|-------|-------|--------|-------------|-------------|
| #50 | Edit issue state | issue-50 | 3 files | 0 |
| #58 | Markdown rendering | issue-58 | 0 files | 2 |

**Location:** ../IssueSpace-issue-50
**Last commit:** abc1234 - "Add GraphQL mutation for state change"

**Location:** ../IssueSpace-issue-58
**Last commit:** def5678 - "Configure marked.js for GFM"

### Recommendations
- issue-58 is 2 commits behind main - consider rebasing
- issue-50 has uncommitted changes - consider committing

### Quick Actions
- `/ke:close 50` - Merge and cleanup issue-50
- `/ke:branchfix 53` - Start next issue in queue
```
