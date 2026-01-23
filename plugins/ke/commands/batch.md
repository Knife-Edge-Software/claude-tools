---
description: Execute batch processing of issue dependency graph
---

# Batch Process Issues

Automatically process an entire issue dependency graph, creating worktrees for parallel tracks and orchestrating execution across multiple terminals.

## Usage

```
/ke:batch [--milestone <name>] [--label <label>] [--dry-run]
```

- Use `--milestone <name>` to process issues in a specific milestone
- Use `--label <label>` to filter to specific labels
- Use `--dry-run` to preview the execution plan without creating worktrees

## Instructions

You are tasked with orchestrating batch execution of multiple issues based on their dependency graph.

### Step 1: Generate the Batch Plan

Run `/ke:map` with the `--json` flag to generate a machine-readable execution plan:

```bash
# If milestone specified
/ke:map --milestone "<milestone>" --json

# If label specified
/ke:map --label "<label>" --json

# If both specified
/ke:map --milestone "<milestone>" --label "<label>" --json

# If neither specified
/ke:map --json
```

This creates `ke-batch-plan.json` in the repository root.

### Step 2: Validate the Plan

Read and validate the generated plan:

```bash
cat ke-batch-plan.json
```

**Check for issues:**
1. **Unplanned issues**: If `unplanned` array is not empty, warn the user:
   ```
   Warning: The following issues have no implementation plans:
   - #52: [title]
   - #56: [title]

   Run `/ke:plan <issue-number>` for each, then re-run `/ke:batch`.
   Continue without these issues? (yes/no)
   ```

2. **Circular dependencies**: If detected during map, abort:
   ```
   Error: Circular dependency detected. Cannot proceed with batch processing.
   Please resolve the circular dependency manually.
   ```

3. **Empty plan**: If no tracks or issues:
   ```
   No issues to process. Nothing to do.
   ```

### Step 3: Preview the Execution (always, or if `--dry-run`)

Display the execution plan to the user:

```markdown
## Batch Execution Plan

**Repository:** owner/repo
**Base branch:** main
**Tracks:** 3 parallel execution tracks

### Track A: Auth System
Sequential chain (each depends on previous):
```
issue-42 (main)
    └── issue-45 (from issue-42)
        └── issue-47 (from issue-45)
```
- #42: Add auth middleware → #45: Add login endpoint → #47: Add logout endpoint

### Track B: UI Components
Sequential chain:
```
issue-50 (main)
    └── issue-51 (from issue-50)
```
- #50: Button hover states → #51: Button loading states

### Track C: Independent
No dependencies:
- #53: Date parsing fix
- #54: Typo fixes

### Summary
- **Total issues:** 7
- **Parallel tracks:** 3
- **Estimated worktrees:** 5

### Worktrees to Create
| Worktree | Branch | Based On | Issues |
|----------|--------|----------|--------|
| repo-issue-42 | issue-42 | main | #42, #45, #47 (sequential) |
| repo-issue-50 | issue-50 | main | #50, #51 (sequential) |
| repo-issue-53 | issue-53 | main | #53, #54 (batch) |
```

**If `--dry-run`:** Stop here and do not proceed to execution.

### Step 4: Confirm Execution

Ask the user to confirm:

```
Ready to start batch execution?

This will:
1. Create 3 worktrees
2. Launch ke-orchestrator.ps1 to manage parallel execution
3. Open 3 terminal windows (one per track)

Proceed? (yes/no)
```

### Step 5: Create State Directory

Create the batch state directory for orchestration:

```bash
mkdir -p ke-batch-state
echo '{"status": "initializing", "started_at": "'$(date -Iseconds)'"}' > ke-batch-state/state.json
```

### Step 6: Create All Worktrees

Create worktrees for each track based on dependency chains:

**For each track in the plan:**

1. **Identify the root issue** (first issue with no dependencies within the track)
2. **Create worktree for root issue:**
   ```bash
   git worktree add ../<repo>-issue-<root-number> -b issue-<root-number> main
   ```
3. **For each subsequent issue in the chain**, the worktree will be created by the orchestrator when the parent completes (using `--from`)

**Create track state files:**
```bash
mkdir -p ke-batch-state/track-A
echo "pending" > ke-batch-state/track-A/status.txt
echo "" > ke-batch-state/track-A/current-issue.txt
```

### Step 7: Generate Orchestrator Config

Create the orchestrator configuration file:

```bash
cat > ke-batch-state/config.json << 'EOF'
{
  "plan_file": "ke-batch-plan.json",
  "state_dir": "ke-batch-state",
  "repo_path": "/absolute/path/to/repo",
  "tracks": [
    {
      "id": "A",
      "name": "Auth System",
      "worktree": "../repo-issue-42",
      "issues": [42, 45, 47],
      "current_index": 0
    },
    {
      "id": "B",
      "name": "UI Components",
      "worktree": "../repo-issue-50",
      "issues": [50, 51],
      "current_index": 0
    },
    {
      "id": "C",
      "name": "Independent",
      "worktree": "../repo-issue-53",
      "issues": [53, 54],
      "current_index": 0
    }
  ]
}
EOF
```

### Step 8: Launch Orchestrator

Launch the PowerShell orchestrator script:

```bash
# Find the orchestrator script (in the ke plugin directory)
powershell.exe -ExecutionPolicy Bypass -File "<ke-plugin-path>/scripts/ke-orchestrator.ps1" -ConfigPath "ke-batch-state/config.json"
```

**Note:** The orchestrator runs as a separate process and will:
1. Open Windows Terminal tabs for each track
2. Monitor completion signals from each track
3. Create dependent worktrees when parents complete
4. Report overall progress

### Step 9: Report Launch Status

```markdown
## Batch Execution Started

**Orchestrator launched:** ke-orchestrator.ps1
**State directory:** ke-batch-state/
**Config file:** ke-batch-state/config.json

### Tracks Running
| Track | Terminal | Status | Current Issue |
|-------|----------|--------|---------------|
| A | Tab 1 | Starting | #42 |
| B | Tab 2 | Starting | #50 |
| C | Tab 3 | Starting | #53 |

### Monitoring
- Check progress: `/ke:batch-status`
- View logs: `cat ke-batch-state/track-A/log.txt`
- Stop execution: Close terminal windows or run `/ke:batch-abort`

### When Complete
After all tracks finish, run `/ke:cascade` to merge everything back to main.
```

### Important

- **DO NOT** implement any issues directly - the orchestrator handles that
- **DO NOT** modify the state files manually - the orchestrator and Claude sessions manage them
- Ensure the `ke-orchestrator.ps1` script exists before launching
- If the orchestrator fails to launch, provide manual instructions for running tracks sequentially

### Manual Fallback

If the orchestrator cannot be launched (script not found, PowerShell issues, etc.), provide manual instructions:

```markdown
## Manual Execution (Orchestrator Unavailable)

Run these commands in separate terminals:

### Terminal 1 (Track A):
```bash
cd ../repo-issue-42
claude -p "/ke:branchfix 42 45 47"
```

### Terminal 2 (Track B):
```bash
cd ../repo-issue-50
claude -p "/ke:branchfix 50 51"
```

### Terminal 3 (Track C):
```bash
cd ../repo-issue-53
claude -p "/ke:branchfix 53 54"
```

When all terminals complete, return here and run `/ke:cascade` to merge.
```
