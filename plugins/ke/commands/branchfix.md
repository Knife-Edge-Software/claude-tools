# Fix GitHub Issue in Worktree

Implement an entire GitHub issue in a dedicated git worktree, keeping the main working directory clean.

## Usage

```
/ke:branchfix [issue-number]
```

Issue number is optional if an issue has already been discussed in the current conversation.

## Instructions

You are tasked with fully implementing a GitHub issue in a separate git worktree based on its implementation plan.

### Step 0: Determine the Issue Number(s)

- If `$ARGUMENTS` is provided and non-empty, parse it for issue numbers
  - Multiple issue numbers can be provided (e.g., `42 43 44` or `42, 43, 44` or `#42 #43`)
  - Extract all numeric issue identifiers from the arguments
- Otherwise, infer the issue number using these sources (in priority order):
  1. Conversation context (previously discussed issue, URL mentioned, `gh issue view` output)
  2. Current branch name (e.g., `issue-42` or `fix-42` suggests issue #42)
  3. Recent commits referencing issues (e.g., `Fix #42` in commit messages)
  4. Open issues assigned to the current user (`gh issue list --assignee @me`)
  5. Recently updated open issues (`gh issue list --state open --limit 5`)
- If no issue number is provided, make your best guess based on the above sources, then **ask the user to confirm** before proceeding:
  ```
  No issue number provided. Based on [source], I believe you want to work on:
  - #42: [Issue title]

  Is this correct? (yes/no/specify different issue)
  ```

**If multiple issue numbers are provided:**
- All issues will be implemented in the **same worktree** under a **single branch**
- The branch and worktree are named after the **first issue** (e.g., `issue-42` for `/ke:branchfix 42 43 44`)
- Process each issue sequentially (complete all steps for issue 1, then all steps for issue 2, etc.)
- Commit after each issue is complete before starting the next one
- Track the outcome of each issue (success, failure, skipped, etc.)
- After processing ALL issues, provide a summary report (see "Final Summary Report" section at the end)

**Why same worktree for multiple issues:**
- Related issues often touch the same files (e.g., edit features #50-55 all modify graphql.rs, commands.rs, main.js)
- Sequential work in one worktree avoids merge conflicts
- Each issue builds on patterns established by previous issues
- Commits after each issue create checkpoints for rollback if needed

### Step 1: Fetch the Issue and Plan

Use `gh issue view <issue-number> --comments` to read the issue and find the implementation plan comment.

### Step 2: Check for Existing Worktree

Before creating a new worktree, check if one already exists for this issue:

```bash
git worktree list | grep "issue-<issue-number>"
```

**If a worktree already exists:**

1. Check its status (uncommitted changes, last commit, etc.):
   ```bash
   git -C <worktree-path> status --porcelain
   git -C <worktree-path> log -1 --format="%h %s (%cr)"
   ```

2. Present the user with options:
   ```
   A worktree already exists for issue #42:
   - Location: /projects/myapp-issue-42
   - Branch: issue-42
   - Last commit: abc1234 "WIP: Add state mutation" (2 hours ago)
   - Uncommitted changes: 3 files

   How would you like to proceed?
   1. **Resume** - Continue working in the existing worktree
   2. **Restart** - Delete worktree and start fresh
   3. **Abort** - Cancel and keep existing worktree unchanged
   ```

3. Based on user response:
   - **Resume**: Skip to Step 3 (change to worktree directory) and continue implementation
   - **Restart**: Remove existing worktree (`git worktree remove <path> --force`), delete branch (`git branch -D issue-<number>`), then create fresh worktree
   - **Abort**: Stop processing this issue, move to next issue (if batch) or exit

**If no worktree exists:**

### Step 2a: Create a Git Worktree

Create a new branch and worktree for this issue:

**For single issue or first issue in a batch:**
1. Create a branch named `issue-<issue-number>` (e.g., `issue-42`)
2. Create a worktree in a sibling directory named `<repo-name>-issue-<issue-number>`
   - For example, if working in `/projects/myapp`, create worktree at `/projects/myapp-issue-42`
3. Use: `git worktree add ../<repo-name>-issue-<issue-number> -b issue-<issue-number>`

**For subsequent issues in a batch (e.g., `/ke:branchfix 42 43 44`):**
- Skip worktree creation - continue using the worktree created for the first issue
- All issues share the same branch and worktree
- Commit after completing each issue before starting the next

**IMPORTANT:** After creating the worktree, inform the user:
- The worktree location
- The branch name
- All issues that will be implemented in this worktree (if multiple)
- That they can use `/ke:close` to merge and clean up when done

Example message (single issue):
```
Created git worktree for issue #42:
- Branch: issue-42
- Location: /projects/myapp-issue-42

When implementation is complete, use /ke:close to merge and remove the worktree.
```

Example message (multiple issues):
```
Created git worktree for issues #42, #43, #44:
- Branch: issue-42
- Location: /projects/myapp-issue-42
- Issues to implement: #42 → #43 → #44 (sequentially, with commits between each)

When all implementations are complete, use /ke:close to merge and remove the worktree.
```

### Step 3: Change to Worktree Directory

Change the working directory to the new worktree before making any changes.

### Step 4: Implement the Solution

Implement ALL steps from the implementation plan:
- Make all necessary code changes in the worktree
- Follow existing patterns and conventions in the codebase
- Keep changes focused on what the plan specifies

### Step 5: Commit and Update the Issue

**Commit the changes** for this issue before posting the completion comment:
```bash
git add -A
git commit -m "Fix #<issue-number>: <brief description>"
```

**Post a completion comment** on the issue using `gh issue comment`:

```markdown
## Implementation Complete

### Worktree
- Branch: `issue-<issue-number>`
- Location: `<worktree-path>`
- Commit: `<commit-hash>`

### Changes Made
- `path/to/file.ts` - [brief description of change]
- `path/to/other.ts` - [brief description of change]

### Notes
[Any relevant notes about the implementation, decisions made, or things to watch for]

### Next Steps
Use `/ke:close` to merge changes and remove the worktree.

---
*Generated by Claude Code*
```

**For multiple issues:** Repeat Steps 4-5 for each issue before moving to the next. Each issue gets its own commit and completion comment.

### Step 6: Ask for Review

After updating the issue, ask the user to review the changes before committing.

### Important

- **DO commit** after each issue is complete (creates checkpoints for rollback)
- Do NOT push any changes (that happens in /ke:close)
- Implement ALL steps from the plan
- Always ask the user to review before finishing
- If the plan is missing or unclear, ask for clarification before implementing

### Final Summary Report (for multiple issues)

When multiple issues were processed, provide a summary table at the end:

```markdown
## Issues Processed

**Worktree:** `../repo-issue-42` (branch: `issue-42`)

| Issue | Title | Status | Commit |
|-------|-------|--------|--------|
| #42 | [Issue title] | ✅ Implemented | abc1234 |
| #43 | [Issue title] | ✅ Resumed & completed | def5678 |
| #44 | [Issue title] | ❌ Failed | - |
| #45 | [Issue title] | ⏭️ Aborted | Worktree kept |

### Summary
- **Implemented:** 1
- **Resumed:** 1
- **Failed:** 1
- **Aborted:** 1

### Next Steps
Use `/ke:close 42` to merge all changes and remove the worktree.
```
