---
description: Assign users to a GitHub issue
---

# Assign GitHub Issue

Assign or unassign users to/from a GitHub issue.

## Usage

```
/ke:assign [issue-number] [user...]
/ke:assign [issue-number] --me
/ke:assign [issue-number] --remove <user>
/ke:assign [issue-number] --clear
```

### Options
- `--me` - Assign yourself to the issue
- `--remove <user>` - Remove a user from assignees
- `--clear` - Remove all assignees

### Examples
```
/ke:assign 42 --me
/ke:assign 42 johndoe
/ke:assign 42 johndoe janedoe
/ke:assign 42 --remove johndoe
/ke:assign 42 --clear
/ke:assign --me          # Assigns current issue (from branch name)
```

## Instructions

You are tasked with managing assignees on a GitHub issue.

### Step 0: Parse Arguments

Parse `$ARGUMENTS` for:
1. **Issue number** (optional) - Infer from branch if not provided
2. **Users** - Username(s) to assign
3. **Flags** - `--me`, `--remove`, `--clear`

**If no issue number:**
- Infer from current branch name (`issue-42` → #42)
- Or from conversation context
- Or ask user which issue

### Step 1: Get Current Assignees

```bash
gh issue view <issue-number> --json assignees --jq '.assignees[].login'
```

### Step 2: Determine Action

**If `--me` flag:**
```bash
# Get current user
CURRENT_USER=$(gh api user --jq '.login')
gh issue edit <issue-number> --add-assignee "$CURRENT_USER"
```

**If `--remove <user>` flag:**
```bash
gh issue edit <issue-number> --remove-assignee "<user>"
```

**If `--clear` flag:**
```bash
# Get all current assignees and remove them
gh issue edit <issue-number> --remove-assignee "<user1>,<user2>,..."
```

**If usernames provided:**
```bash
gh issue edit <issue-number> --add-assignee "<user1>,<user2>"
```

### Step 3: Confirm Changes

Show the updated assignee list:

```
Issue #42: <issue-title>

Assignees updated:
- Before: @johndoe
- After: @johndoe, @janedoe

Added: @janedoe
```

Or for removals:
```
Issue #42: <issue-title>

Assignees updated:
- Before: @johndoe, @janedoe
- After: @johndoe

Removed: @janedoe
```

### Step 4: Offer to Start Work (if self-assigned)

If user assigned themselves:
```
You're now assigned to issue #42.

Ready to start?
- `/ke:plan 42` - Create implementation plan
- `/ke:branchfix 42` - Start working in a worktree
```

### Error Handling

**User not found or no access:**
```
Error: User 'unknownuser' cannot be assigned to this issue.
They may not have access to this repository.
```

**Already assigned:**
```
@johndoe is already assigned to issue #42.
Current assignees: @johndoe, @janedoe
```

### Important

- Users must have access to the repository to be assigned
- Use `--me` as a shortcut for self-assignment
- Multiple users can be assigned in one command
- The `--clear` flag removes ALL assignees, use with caution
