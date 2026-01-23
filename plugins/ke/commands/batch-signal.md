---
description: Signal batch execution state to orchestrator
---

# Batch Signal

Signal state changes to the batch orchestrator. Used by Claude sessions running within a batch to communicate completion, failures, or other status updates.

## Usage

```
/ke:batch-signal <status> [issue-number] [--reason <reason>]
```

**Status values:**
- `complete` - Issue implementation finished successfully
- `failed` - Issue implementation failed
- `blocked` - Issue cannot proceed (dependency issue, unclear requirements, etc.)
- `skipped` - Issue was skipped (already done, not applicable, etc.)

## Instructions

You are tasked with signaling state to the batch orchestrator.

### Step 1: Detect Batch Mode

Check if running in batch mode by looking for the state directory:

```bash
# Check for batch state directory
ls ke-batch-state/ 2>/dev/null || ls ../ke-batch-state/ 2>/dev/null
```

**If state directory not found:**
```
Not running in batch mode. This command is only used during /ke:batch execution.
```

### Step 2: Determine Track

Identify which track this session belongs to by checking the current worktree:

```bash
# Get current directory name
basename "$(pwd)"
# Example: myapp-issue-42

# Extract issue number
# issue-42 -> Track can be found in config
```

Read the config to find the track:
```bash
cat ke-batch-state/config.json
# or
cat ../ke-batch-state/config.json
```

### Step 3: Parse Arguments

Extract from `$ARGUMENTS`:
- **Status**: First word (complete, failed, blocked, skipped)
- **Issue number**: Optional, defaults to current issue from track state
- **Reason**: Optional, from `--reason` flag

### Step 4: Update State Files

**Update track status:**
```bash
# Find the correct state directory
STATE_DIR="ke-batch-state"
if [ ! -d "$STATE_DIR" ]; then
    STATE_DIR="../ke-batch-state"
fi

TRACK_ID="A"  # Determined from config

# Write status
echo "<status>" > "$STATE_DIR/track-$TRACK_ID/status.txt"

# Write current issue (if provided)
echo "<issue-number>" > "$STATE_DIR/track-$TRACK_ID/current-issue.txt"

# Append to log
echo "$(date -Iseconds) [<status>] Issue #<number>: <reason>" >> "$STATE_DIR/track-$TRACK_ID/log.txt"
```

### Step 5: Confirm Signal

```markdown
## Batch Signal Sent

- **Track:** A (Auth System)
- **Status:** complete
- **Issue:** #42
- **Time:** 2026-01-22T10:45:00

The orchestrator will pick up this signal on its next poll cycle.
```

### Status Meanings

| Status | Meaning | Orchestrator Action |
|--------|---------|---------------------|
| `complete` | Issue done, ready for next | Advance to next issue or mark track complete |
| `failed` | Implementation failed | Pause track, alert user |
| `blocked` | Cannot proceed | Pause track, wait for resolution |
| `skipped` | Issue skipped | Advance to next issue |

### Auto-Signaling

This command is typically called automatically by `/ke:close` when running in batch mode. You can also call it manually if needed:

```
# After completing an issue manually
/ke:batch-signal complete 42

# If implementation failed
/ke:batch-signal failed 42 --reason "Tests failing, need user input"

# If blocked by external factor
/ke:batch-signal blocked 42 --reason "Waiting for API documentation"
```

### Important

- This command only works during batch execution (when `ke-batch-state/` exists)
- The orchestrator polls state files periodically (default: every 10 seconds)
- Multiple signals can be sent for the same issue (latest wins)
- Log file preserves history of all signals for debugging
