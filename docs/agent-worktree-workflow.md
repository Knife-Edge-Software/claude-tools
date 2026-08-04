# Agent Worktree Workflow

This workflow sends one issue, or a related batch of issues, to an isolated Git worktree. It opens Codex and Claude beside a PowerShell control pane so implementation, review, finalization, and QA handoff stay together in one Windows Terminal tab.

The normal path is:

```text
original checkout
    |
    | kebatchfix-codex 42
    v
issue worktree + three-pane terminal
    |
    | Codex implements -> Claude reviews -> keclose
    v
merge and push, then close / QA / unchanged
    |
    | close the terminal tab -> kecleanup
    v
worktree and issue branch removed safely
```

## Requirements and setup

Install these commands and make sure each is available on `PATH`:

- Git 2.x or newer
- [GitHub CLI](https://cli.github.com/), authenticated with `gh auth login`
- [Codex CLI](https://developers.openai.com/codex/cli/)
- Claude Code
- [Windows Terminal](https://learn.microsoft.com/windows/terminal/command-line-arguments), including its `wt` command
- PowerShell

Put this repository's directory on `PATH` so the scripts can be called by name. For the current PowerShell session:

```powershell
$env:Path += ';C:\dev\github\KE\claude-tools'
```

Use your actual clone location if it differs. Add the same directory to your user `PATH` to make the commands available in future terminals.

Both model panes start in unrestricted modes: Codex uses `--yolo`, and Claude uses `--dangerously-skip-permissions`. Only run this workflow in repositories and worktrees you trust.

## Quick start

From the original checkout, while it is on the branch that should receive the finished work:

```powershell
kebatchfix-codex 42
```

For related issues that should be implemented and merged together:

```powershell
kebatchfix-codex 42 43 44
```

The first issue names the worktree and branch. In this example they are a sibling directory named `<repository>-issue-42` and a branch named `issue-42`. All issue numbers are stored in the batch metadata and are handled together by `keclose`.

When implementation and review are complete, run this in the worktree's PowerShell pane:

```powershell
keclose
```

No issue argument is needed. The script infers the issue batch, issue branch, worktree, and target branch from the current checkout and the stored metadata.

## The three panes

`kebatchfix-codex` opens one Windows Terminal tab with three side-by-side panes:

| Pane | Role | What to do there |
| --- | --- | --- |
| Left | Codex implementer | Discuss implementation, answer questions, and ask Codex to make or revise commits. |
| Middle | Claude reviewer | Ask for an independent review of the complete target-branch-to-HEAD change. After merging, it can also help write a detailed QA test plan. |
| Right | PowerShell control | Watch dependency setup, inspect the repository if needed, and run `kereview`, `keclose`, or other commands in the correct worktree context. |

Codex receives instructions to read every issue and its comments, follow the implementation plan and repository instructions, implement and test each issue, create a separate commit for each issue, and post a completion comment. It is explicitly told not to merge, push, or remove the worktree.

Claude starts as a conversational second collaborator. It is told to inspect the complete change, look for correctness, regression, security, and test-coverage problems, and avoid modifying code unless asked.

The PowerShell pane starts in the issue worktree. If the repository has a root `package.json`, it runs `npm install`. If it has `src-tauri/Cargo.toml`, it also runs `cargo fetch` and a debug `cargo build`.

## Review loop

The easiest review flow is conversational:

1. Let Codex finish and commit the implementation.
2. In the Claude pane, ask Claude to review the entire issue branch against the target branch.
3. Discuss each finding. Ask Codex to fix valid findings and commit the fixes.
4. If HEAD changes, ask Claude to review the new HEAD again.
5. When no unresolved findings remain, run `keclose` in the PowerShell pane.

If no saved automated approval matches the current HEAD, `keclose` displays the exact commit hash and asks whether that exact HEAD was reviewed with no unresolved findings. Answering yes records the conversational approval. Any later commit changes HEAD and invalidates that approval automatically.

### Optional scripted review

`kereview` is available when a captured, non-conversational review is useful. From the issue worktree, it infers the issue:

```powershell
kereview                 # Claude reviewer
kereview -With Codex     # Codex reviewer
```

From the original checkout, pass the first issue number:

```powershell
kereview 42
```

The output is shown in the terminal and saved under the shared review metadata directory. The script then asks whether the review passed with no unresolved findings. An approval applies only to the recorded branch, base branch, and exact HEAD.

## Finalizing with `keclose`

Run `keclose` from the right pane after review. Before changing anything, it verifies that:

- the original checkout is still on the expected target branch;
- both the original checkout and issue worktree are clean;
- the issue branch and target branch are valid;
- an `origin` remote exists; and
- review approval matches the exact implementation HEAD, or you explicitly confirm the conversational review.

The control shell moves itself from the issue worktree to the original checkout. This avoids keeping the worktree busy during later cleanup and lets the same pane remain useful after the merge.

Next, choose what should happen to every issue in the batch:

1. **Close as resolved** closes open issues with a comment identifying the merge and reviewed implementation commits.
2. **Keep open for QA** reopens closed issues when necessary, optionally assigns a GitHub user, and comments that the implementation was merged and awaits QA.
3. **Leave issue state unchanged** merges and pushes without changing the issues.

After confirmation, `keclose` fetches the target branch, fast-forwards it from `origin`, performs a `--no-ff` merge of the issue branch, pushes the target branch, and applies the selected issue disposition.

For a QA handoff, select option 2 and enter the tester's GitHub username. After the merge, keep the terminal tab open and ask Claude or Codex to add the detailed test plan to the issue while the implementation context is still available.

The worktree and issue branch are intentionally retained after finalization. This is what allows both model conversations to continue even though the implementation has already been merged.

### Explicit options

These forms are useful for repeatable or automated operation:

```powershell
keclose -Disposition QA -Assignee tester-name
keclose -Disposition Close
keclose 42 43 -Disposition Unchanged
keclose -Into release/2.x
```

`-Yes` accepts the final confirmation and defaults the disposition to `Close`, but it does not manufacture review approval. If no exact-HEAD approval exists, the command stops so review cannot be silently bypassed.

```powershell
keclose -Disposition Close -Yes
```

`-SkipReview` is the explicit escape hatch. Combining it with `-Yes` performs a non-interactive finalization without review confirmation, so reserve it for exceptional cases where bypassing the review gate is intentional:

```powershell
keclose -Disposition Close -SkipReview -Yes
```

## Cleanup

Each of the three panes holds an issue-specific lock while it is open. `kecleanup` removes a finalized worktree only when all of these conditions are true:

- no workflow pane still holds its lock;
- the command is not running from inside that worktree;
- the worktree is clean; and
- the issue branch is fully merged into its recorded target branch.

Close the Windows Terminal tab when the conversations are no longer needed. The next `kebatchfix-codex` run automatically attempts quiet cleanup of any older finalized worktrees. You can also request cleanup from the original checkout:

```powershell
kecleanup       # all eligible finalized worktrees
kecleanup 42    # one batch, identified by its first issue
```

If a safety condition is not met, cleanup skips that worktree instead of forcing its removal. Correct the reported condition and run it again.

## State and safety model

All workflow state lives in the repository's shared Git directory, normally under `.git\agenttools`. It is shared by the original checkout and every linked worktree and is not committed to the repository.

| Path | Purpose |
| --- | --- |
| `.git\agenttools\issues\issue-<N>.json` | Batch issues, branch, worktree, target branch, lifecycle status, and final merge information. |
| `.git\agenttools\reviews\issue-<N>.json` | Current approval status and the exact implementation HEAD it covers. |
| `.git\agenttools\reviews\issue-<N>-<SHA>-<reviewer>.txt` | Captured output from optional `kereview` runs. |
| `.git\agenttools\locks\issue-<N>\*.lock` | Live pane locks used to defer cleanup. |

`<N>` is always the first issue in a batch. The metadata file contains the complete issue list.

The design separates responsibilities deliberately:

- the launcher creates or resumes the worktree deterministically;
- the agents change and review code only in that worktree;
- `keclose` owns the merge, push, and issue disposition; and
- `kecleanup` owns eventual worktree and branch removal.

## Recovery and troubleshooting

### Restarting Codex with unrestricted permissions

If a Codex session was started without `--yolo`, stop it and resume from a terminal in the same worktree:

```powershell
codex --yolo resume --last
```

New sessions launched by `kebatchfix-codex` already include `--yolo`.

### The original checkout or worktree is dirty

`keclose` will not merge while either checkout has uncommitted changes. Commit, stash, or intentionally discard the relevant changes, then rerun `keclose`. Do not remove unrelated work merely to satisfy the check.

### Commits changed after review

Ask the reviewer to inspect the new HEAD, then run `keclose` again. A prior approval does not carry forward to a different commit.

### Fetch or fast-forward failed

No issue-branch merge has occurred. Reconcile the target branch with `origin`, make sure the original checkout is on the recorded target branch, and rerun `keclose`.

### The merge conflicted

Resolve and commit the merge in the original checkout, or abort it with `git merge --abort`. Then rerun `keclose`. The issue worktree is preserved either way.

### Push or GitHub issue update failed

The script reports how far it got and preserves both checkouts. Correct authentication, network, repository-rule, or issue-permission problems and rerun it. A retry can safely continue when the issue branch is already merged; `keclose` warns that there are no new unmerged commits and proceeds with the remaining push or issue work.

If the existing control pane is still open, parameterless retry works because it retains the issue context even after moving to the original checkout. From a fresh terminal in the original checkout, pass the first issue number explicitly:

```powershell
keclose 42
```

### Cleanup says panes are still open

Close the issue's Windows Terminal tab and rerun `kecleanup`. If a terminal process crashed, its file handles should be released automatically; stale lock files alone do not block cleanup because `kecleanup` tests whether each file is actively locked.

### Resuming an existing batch

Run the same launcher command again from the original checkout:

```powershell
kebatchfix-codex 42 43 44
```

If the sibling worktree is registered on the expected `issue-42` branch, it is reused and a new three-pane tab opens. Existing changes are preserved.

## Legacy `/ke:*` commands

The Claude Code plugin and its `/ke:*` commands remain in this repository. They can still be used independently while this agent-neutral worktree workflow is adopted. The new scripts do not require removing or archiving the legacy plugin.
