---
description: Create a new GitHub issue
---

# Create GitHub Issue

Create a new GitHub issue based on a description.

## Usage

```
/ke:create <description> [--milestone <name>] [--assignee <user>]
```

### Options
- `--milestone <name>` - Assign to a milestone (by name or number)
- `--assignee <user>` - Assign to a user (use `@me` for self)

### Examples
```
/ke:create Add dark mode toggle
/ke:create Fix login timeout --assignee @me
/ke:create Refactor auth module --milestone v2.0 --assignee johndoe
```

## Instructions

You are tasked with creating a new GitHub issue based on the provided description.

### Step 1: Parse Arguments

Parse `$ARGUMENTS` for:
1. **Description** - Everything that's not a flag
2. **--milestone** - Optional milestone name/number
3. **--assignee** - Optional assignee username (`@me` = current user)

If the description is empty or unclear, ask the user for clarification.

### Step 2: Validate Options (if provided)

**If --milestone specified:**
```bash
# List available milestones
gh api repos/{owner}/{repo}/milestones --jq '.[].title'
```
- If milestone doesn't exist, show available milestones and ask user to choose

**If --assignee specified:**
- If `@me`, get current user: `gh api user --jq '.login'`
- Validate user has access to repo (will fail on gh issue create if not)

### Step 3: Create the Issue

Build the `gh issue create` command with appropriate flags:

```bash
gh issue create \
  --title "<concise title>" \
  --body "$(cat <<'EOF'
## Description
[Clear description of what needs to be done]

## Details
[Any additional context, requirements, or acceptance criteria]

---
*Created by Claude Code*
EOF
)" \
  [--milestone "<milestone>"] \
  [--assignee "<user>"]
```

Guidelines for the issue:
- Title should be concise and descriptive (imperative mood, e.g., "Add dark mode toggle")
- Body should expand on the request with enough detail for implementation
- Include any relevant context from the conversation

### Step 4: Report the Issue

After creating the issue, tell the user:
- The issue number and title
- A link to the issue
- Milestone and assignee (if set)

Example:
```
Created issue #67: Add dark mode toggle
- URL: https://github.com/owner/repo/issues/67
- Milestone: v2.0
- Assignee: @johndoe
```

### Step 5: Offer Next Steps

After creating the issue, offer:
```
Would you like to:
- `/ke:plan 67` - Create an implementation plan
- `/ke:branchfix 67` - Start working on it now
```

### Important

- Do NOT make any code changes
- Do NOT create implementation plans (use `/ke:plan` for that)
- If the description is missing or empty, ask the user what issue they want to create
- If milestone doesn't exist, offer to create without it or let user choose from available milestones
