# Comment on GitHub Issue

Add a comment to a GitHub issue.

## Usage

```
/ke:comment [issue-number] <message>
```

### Examples
```
/ke:comment 42 This is blocked by the API migration
/ke:comment Need more details on the expected behavior
/ke:comment 42 --status in-progress
```

### Special Flags
- `--status <status>` - Add a status update (in-progress, blocked, needs-review, on-hold)

## Instructions

You are tasked with adding a comment to a GitHub issue.

### Step 0: Parse Arguments

Parse `$ARGUMENTS` for:
1. **Issue number** (optional) - First number found, or infer from context
2. **Message** - The comment text
3. **--status** (optional) - Status update flag

**If no issue number in arguments:**
- Infer from current branch name (`issue-42` → #42)
- Or from conversation context
- Or ask user which issue to comment on

**If no message provided:**
- Ask user what they want to say

### Step 1: Format the Comment

**For regular comments:**
```markdown
[User's message]

---
*Posted by Claude Code*
```

**For status updates (--status flag):**
```markdown
## Status Update: [Status]

[User's message]

---
*Posted by Claude Code*
```

Status badges:
- `in-progress` → 🔄 **In Progress**
- `blocked` → 🚫 **Blocked**
- `needs-review` → 👀 **Needs Review**
- `on-hold` → ⏸️ **On Hold**

### Step 2: Post the Comment

```bash
gh issue comment <issue-number> --body "<formatted-message>"
```

### Step 3: Confirm

Tell the user:
```
Comment added to issue #42: <issue-title>
URL: <comment-url>
```

### Smart Features

**If message mentions other issues:**
- The `#123` references will automatically link in GitHub

**If message indicates blocking:**
- If message contains "blocked by #X", suggest: "Would you like to add a dependency note to the issue?"

**If message is a question:**
- Remind user: "You'll be notified when someone responds"

### Important

- Keep comments concise and actionable
- Don't post duplicate comments
- If the issue doesn't exist, inform the user
- For long discussions, suggest creating a new issue instead
