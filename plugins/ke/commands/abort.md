# Abort Issue Work

Abandon work on an issue, removing the worktree and branch.

## Usage

```
/ke:abort [issue-number]
```

### Examples
```
/ke:abort 42
/ke:abort        # Aborts current issue (from branch name or worktree)
```

## Instructions

You are tasked with abandoning work on a GitHub issue by cleaning up the worktree and branch.

### Step 0: Determine the Issue Number

- If `$ARGUMENTS` contains an issue number, use it
- Otherwise, infer from:
  1. Current branch name (e.g., `issue-42` → #42)
  2. Current worktree path (e.g., `repo-issue-42` → #42)
  3. Conversation context
- If no issue found, ask the user which issue to abort

### Step 1: Find the Worktree

```bash
git worktree list | grep "issue-<issue-number>"
```

**If no worktree exists:**
- Check if branch exists: `git branch --list "issue-<issue-number>"`
- If branch exists but no worktree, skip to Step 4 (delete branch only)
- If neither exists, inform user: "No worktree or branch found for issue #42"

### Step 2: Check for Uncommitted Changes

```bash
git -C <worktree-path> status --porcelain
```

**If uncommitted changes exist:**

Show the user what will be lost:
```
⚠️ WARNING: Uncommitted changes will be lost!

Worktree: ../repo-issue-42
Branch: issue-42

Modified files:
- src/main.js (15 lines changed)
- src/styles.css (8 lines changed)

How would you like to proceed?
1. **Discard** - Delete everything (changes will be lost forever)
2. **Stash** - Save changes to stash, then delete worktree/branch
3. **Cancel** - Keep worktree and abort the abort
```

**Handle user response:**

- **Discard**: Continue to Step 3
- **Stash**:
  ```bash
  git -C <worktree-path> stash push -m "Aborted issue-<number>: <issue-title>"
  # Note: Stash is tied to the repo, accessible from main worktree
  ```
  Then continue to Step 3
- **Cancel**: Exit without changes

### Step 3: Ensure Not in Worktree

If currently in the worktree being deleted:
```bash
cd <main-worktree-path>
```

Inform user: "Changed directory to main worktree"

### Step 4: Remove Worktree

```bash
git worktree remove <worktree-path> --force
```

If removal fails (e.g., locked):
```bash
git worktree remove <worktree-path> --force
```

### Step 5: Delete Branch

```bash
git branch -D issue-<issue-number>
```

Use `-D` (force delete) since the branch may not be merged.

### Step 6: Confirm Cleanup

```
✅ Aborted work on issue #42: <issue-title>

Cleaned up:
- Worktree: ../repo-issue-42 (removed)
- Branch: issue-42 (deleted)
- Stash: stash@{0} "Aborted issue-42: <title>" (if stashed)

The issue remains open on GitHub. To resume later:
- `/ke:branchfix 42` - Start fresh
```

### Step 7: Optionally Comment on Issue

Ask user:
```
Would you like to add a comment to issue #42 explaining why work was abandoned?
(yes/no)
```

If yes, use `/ke:comment` pattern to post:
```markdown
## Work Abandoned

Work on this issue has been paused/abandoned.

Reason: [Ask user for reason or use "No reason provided"]

---
*Posted by Claude Code*
```

### Important

- **This is destructive** - uncommitted changes can be lost forever
- Always confirm with user before deleting if there are uncommitted changes
- The stash option preserves changes but they must be manually retrieved
- The issue on GitHub is NOT closed - only local work is removed
- If the branch was pushed to remote, inform user it still exists on remote
