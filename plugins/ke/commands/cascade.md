---
description: Merge dependency chains bottom-up with squash to main
---

# Cascade Merge

Merge all issue worktrees back to main using bottom-up merging within chains, then squash-merge each chain to main for a clean history.

## Usage

```
/ke:cascade [--dry-run] [--no-cleanup]
```

- Use `--dry-run` to preview the merge plan without executing
- Use `--no-cleanup` to keep worktrees after merging (for debugging)

## Instructions

You are tasked with merging all completed issue worktrees back to main in the correct order, preserving commit history within chains but squashing when merging to main.

### Step 1: Discover Worktrees

List all issue worktrees:

```bash
git worktree list
```

Parse the output to find worktrees matching the pattern `*-issue-*` or branches named `issue-*`.

**Example output:**
```
/projects/myapp                   abc1234 [main]
/projects/myapp-issue-20          def5678 [issue-20]
/projects/myapp-issue-21          ghi9012 [issue-21]
/projects/myapp-issue-22          jkl3456 [issue-22]
/projects/myapp-issue-30          mno7890 [issue-30]
/projects/myapp-issue-31          pqr1234 [issue-31]
```

### Step 2: Build Dependency Graph

For each issue branch, determine its parent by checking what branch it was created from:

```bash
# Check the merge-base to determine lineage
git merge-base issue-21 issue-20
git merge-base issue-21 main

# If merge-base with issue-20 is more recent than merge-base with main,
# then issue-21 was branched from issue-20
```

**Also check the batch plan if available:**
```bash
cat ke-batch-plan.json 2>/dev/null
```

Build a tree structure:
```
main
├── issue-20
│   └── issue-21
│       └── issue-22
└── issue-30
    └── issue-31
```

### Step 3: Identify Leaf Nodes

Leaf nodes are branches that no other branch depends on:
- `issue-22` (nothing branches from it)
- `issue-31` (nothing branches from it)

### Step 4: Prompt for Testing

Before merging, remind the user to test:

```markdown
## Pre-Merge Testing

The following leaf branches should be tested before merging:

| Branch | Worktree | Issues in Chain |
|--------|----------|-----------------|
| issue-22 | ../myapp-issue-22 | #20 → #21 → #22 |
| issue-31 | ../myapp-issue-31 | #30 → #31 |

**Test each leaf worktree:**
```bash
cd ../myapp-issue-22
npm test && npm run build

cd ../myapp-issue-31
npm test && npm run build
```

Have you tested all leaf branches? (yes/skip/abort)
```

**If user says "skip":** Proceed with warning.
**If user says "abort":** Stop cascade.

### Step 5: Plan the Merge Order

Generate merge plan (bottom-up within chains, then chains to main):

```markdown
## Merge Plan

### Chain 1: issue-20 → issue-21 → issue-22
1. `git checkout issue-21 && git merge issue-22 --no-ff`
2. `git checkout issue-20 && git merge issue-21 --no-ff`
3. `git checkout main && git merge --squash issue-20`
4. `git commit -m "Fix #20, #21, #22: [chain description]"`

### Chain 2: issue-30 → issue-31
1. `git checkout issue-30 && git merge issue-31 --no-ff`
2. `git checkout main && git merge --squash issue-30`
3. `git commit -m "Fix #30, #31: [chain description]"`

**Result:** 2 commits on main (one per chain)
```

**If `--dry-run`:** Stop here and do not execute.

### Step 6: Execute Bottom-Up Merges

For each chain, starting from leaves and working up:

**Example for chain issue-20 → issue-21 → issue-22:**

```bash
# Step 1: Merge leaf into parent
git checkout issue-21
git merge issue-22 --no-ff -m "Merge issue-22 into issue-21"

# Step 2: Merge up to root
git checkout issue-20
git merge issue-21 --no-ff -m "Merge issue-21 into issue-20 (includes #22)"
```

**Handle merge conflicts:**
If a merge fails, stop and report:
```markdown
## Merge Conflict

Conflict merging `issue-22` into `issue-21`:

**Conflicting files:**
- src/auth/middleware.ts

**To resolve:**
1. Open the worktree: `cd ../myapp-issue-21`
2. Resolve conflicts in the listed files
3. Run: `git add . && git commit`
4. Re-run: `/ke:cascade`
```

### Step 7: Squash-Merge Chains to Main

After each chain is fully merged internally, squash-merge to main:

```bash
# Ensure main is up to date
git checkout main
git pull origin main

# Squash-merge the chain root
git merge --squash issue-20

# Create a single commit with all issues
git commit -m "$(cat <<'EOF'
Fix #20, #21, #22: Auth system implementation

- #20: Add auth middleware
- #21: Add login endpoint
- #22: Add logout endpoint

Co-Authored-By: Claude Code <noreply@anthropic.com>
EOF
)"
```

**Repeat for each chain.**

### Step 8: Push to Remote

```bash
git push origin main
```

### Step 9: Cleanup (unless `--no-cleanup`)

Remove all worktrees and branches:

```bash
# Remove worktrees
git worktree remove ../myapp-issue-22
git worktree remove ../myapp-issue-21
git worktree remove ../myapp-issue-20
git worktree remove ../myapp-issue-31
git worktree remove ../myapp-issue-30

# Delete branches
git branch -D issue-22 issue-21 issue-20 issue-31 issue-30

# Remove batch state directory
rm -rf ke-batch-state/
rm -f ke-batch-plan.json
```

### Step 10: Final Report

```markdown
## Cascade Complete

### Commits Added to Main
| Commit | Message | Issues |
|--------|---------|--------|
| abc1234 | Fix #20, #21, #22: Auth system | #20, #21, #22 |
| def5678 | Fix #30, #31: UI improvements | #30, #31 |

### Issues Closed
- #20: Add auth middleware ✅
- #21: Add login endpoint ✅
- #22: Add logout endpoint ✅
- #30: Button hover states ✅
- #31: Button loading states ✅

### Cleanup
- 5 worktrees removed
- 5 branches deleted
- Batch state directory removed

### Next Steps
- Review the commits on main: `git log -2`
- Deploy if ready
```

### Important

- **Always test leaves before merging** - this is your last chance to catch issues
- **Squash to main** keeps history clean (one commit per chain)
- **--no-ff within chains** preserves merge points for debugging
- If any merge fails, the cascade stops and waits for manual resolution
- Re-running `/ke:cascade` after fixing conflicts will continue where it left off
- The batch state directory (`ke-batch-state/`) is removed on successful completion

### Rollback

If something goes wrong after merging to main:

```bash
# Find the commit before the cascade
git log --oneline -10

# Reset to before the cascade (DANGEROUS - loses commits)
git reset --hard <commit-before-cascade>
git push --force origin main  # Only if you pushed

# Or revert specific commits (safer)
git revert <cascade-commit-1> <cascade-commit-2>
```

**Best practice:** Create a backup branch before cascading:
```bash
git branch backup-before-cascade
```
