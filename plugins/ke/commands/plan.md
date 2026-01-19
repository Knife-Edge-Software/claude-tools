---
description: Create an implementation plan for a GitHub issue
---

# Plan GitHub Issue

Review a GitHub issue and create an implementation plan, then post it as a comment on the issue.

## Usage

```
/ke:plan [issue-number]
```

Issue number is optional if an issue has already been discussed in the current conversation.

## Instructions

You are tasked with reviewing a GitHub issue and creating a detailed implementation plan. Do NOT implement any code changes - only create the plan.

### Step 0: Determine the Issue Number(s)

- If `$ARGUMENTS` is provided and non-empty, parse it for issue numbers
  - Multiple issue numbers can be provided (e.g., `42 43 44` or `42, 43, 44` or `#42 #43`)
  - Extract all numeric issue identifiers from the arguments
- Otherwise, check conversation context for an obvious issue (previously discussed issue, URL mentioned, `gh issue view` output)
- If no issue number is provided and nothing obvious in context:
  1. Fetch open issues that have no comments (likely unplanned): `gh issue list --state open --json number,title,createdAt,labels --limit 50`
  2. Filter to issues with 0 comments (check each with `gh issue view <number> --json comments`)
  3. Present the top 10 unplanned issues to the user:
  ```
  No issue number provided. Here are open issues without implementation plans:

  | # | Issue | Title | Labels | Created |
  |---|-------|-------|--------|---------|
  | 1 | #42 | Add dark mode | enhancement | 2 days ago |
  | 2 | #41 | Fix login bug | bug | 3 days ago |
  | ... | ... | ... | ... | ... |

  Which issue(s) would you like to plan? (enter number(s), e.g., "1" or "1 3 5")
  ```
  4. Wait for user response before proceeding

**If multiple issue numbers are provided:**
- Process each issue sequentially (complete all steps for issue 1, then all steps for issue 2, etc.)
- Track the outcome of each issue (success, failure, skipped, etc.)
- After processing ALL issues, provide a summary report (see "Final Summary Report" section at the end)

### Step 1: Fetch the Issue

Use `gh issue view <issue-number> --comments` to read the issue details including title, body, labels, and any existing comments.

### Step 1a: Check for Existing Plan

Look through the issue comments for an existing implementation plan (comments containing "## Implementation Plan" or similar headers).

**If a plan already exists:**

1. Display the existing plan to the user (or a summary if it's long)
2. Ask the user how to proceed:

```
This issue already has an implementation plan (posted [date] by [author]):

---
[Show first ~20 lines of the plan or summary]
---

How would you like to proceed?
1. **Skip** - Keep existing plan, don't create a new one
2. **Update** - Refine/add to the existing plan
3. **Replace** - Discard existing plan and create a new one from scratch
```

3. Based on user response:
   - **Skip**: Report "Skipped - existing plan retained" and move to next issue (if batch)
   - **Update**: Proceed to Step 2, but in Step 4 post a comment that builds on/refines the existing plan (reference what changed)
   - **Replace**: Proceed to Step 2, create fresh plan (optionally note "Replaces previous plan" in the comment)

**If no plan exists:**
- Continue to Step 2

### Step 2: Analyze the Codebase

Based on the issue requirements:
- Identify which files would need to be modified or created
- Understand the existing patterns and architecture relevant to the issue
- Consider dependencies and potential impacts

Use the Explore agent or search tools to thoroughly understand the codebase context.

### Step 3: Evaluate Whether to Split the Issue

Before creating the plan, evaluate whether the issue should be split into sub-issues. Consider splitting when:

- **Multiple independent features** - The issue requests several things that could be implemented and reviewed separately
- **Different code areas** - Changes span unrelated parts of the codebase (e.g., backend + frontend + CLI)
- **Sequential dependencies** - Some parts must be done before others (e.g., "add API endpoint" before "add UI that calls it")
- **Parallelizable work** - Multiple people could work on different parts simultaneously
- **Clearer progress tracking** - Breaking down makes it easier to see progress and estimate completion
- **Risk isolation** - If one part fails or gets reverted, others can proceed independently

**If the issue should NOT be split:**
- Continue to Step 4 to create a single implementation plan

**If the issue SHOULD be split:**
1. Identify the logical sub-issues
2. Determine dependencies between them (which must be done first?)
3. Continue to Step 4, but create plans for each sub-issue
4. In Step 5, create the sub-issues on GitHub with proper dependencies noted

### Step 4: Create the Plan

Create a comprehensive implementation plan that includes:

1. **Summary** - Brief overview of what the issue requires
2. **Files to Modify** - List each file with a brief description of what changes are needed
3. **Implementation Steps** - Ordered list of concrete steps to implement the solution
4. **Risks & Considerations** - Potential issues, edge cases, or decisions that need clarification

**If splitting into sub-issues**, also include:
5. **Sub-issues** - List of sub-issues to create with their dependencies

Post the plan as a comment on the issue using `gh issue comment`. Format the comment in markdown with clear sections.

Use this template for the comment:

```markdown
## Implementation Plan

### Summary
[Brief overview]

### Files to Modify
- `path/to/file.ts` - [what changes]
- `path/to/other.ts` - [what changes]

### Implementation Steps
1. [First step]
2. [Second step]
3. [Continue as needed]

### Risks & Considerations
- [Risk or consideration 1]
- [Risk or consideration 2]

---
*Generated by Claude Code*
```

### Step 5: Create Sub-issues (if splitting)

If Step 3 determined the issue should be split, create sub-issues on GitHub:

1. **Create each sub-issue** using `gh issue create`:
   ```bash
   gh issue create --title "Sub-issue title" --body "Description..." --label "label1,label2"
   ```

2. **Note dependencies** in each sub-issue body using this format:
   ```markdown
   **Depends on:** #124

   <!-- or for multiple dependencies -->
   **Depends on:** #124, #125

   <!-- or if no dependencies -->
   **Depends on:** None (can start immediately)
   ```

3. **Update the parent issue** with a tracking comment:
   ```markdown
   ## Sub-issues

   This issue has been broken down into the following sub-issues:

   | Issue | Title | Depends On | Status |
   |-------|-------|------------|--------|
   | #124 | [Sub-issue 1 title] | None | Open |
   | #125 | [Sub-issue 2 title] | None | Open |
   | #126 | [Sub-issue 3 title] | #124, #125 | Blocked |

   Complete sub-issues in dependency order. This parent issue will be closed when all sub-issues are resolved.
   ```

4. **Apply consistent labels/milestones** - Copy labels and milestone from parent to sub-issues

5. **Keep parent open** as a tracking issue until all sub-issues are complete

### Step 6: Report Changes

After completing the planning process, provide a summary of all issues changed or created.

If more than one issue was involved (created or modified), respond with a summary table:

| Issue | Title | Dependencies |
|-------|-------|--------------|
| #123 | [Title of issue] | None (parent issue) |
| #124 | [Title of sub-issue 1] | None |
| #125 | [Title of sub-issue 2] | #124 |

Include:
- The original issue (if modified)
- Any new sub-issues created
- Dependencies between issues (which issues must be completed before others)

### Important

- Do NOT make any code changes
- Do NOT create or modify any files other than posting GitHub comments and creating sub-issues
- If the issue is unclear, note what clarifications are needed in the Risks & Considerations section
- If the issue appears to already be resolved or is invalid, note this in your comment instead of a full plan
- When creating sub-issues, use labels and milestones consistent with the parent issue

### Final Summary Report (for multiple issues)

When multiple issues were processed, provide a summary table at the end:

```markdown
## Issues Processed

| Issue | Title | Status | Sub-issues Created |
|-------|-------|--------|-------------------|
| #42 | [Issue title] | ✅ Planned | None |
| #43 | [Issue title] | ✅ Planned | #46, #47 |
| #44 | [Issue title] | ❌ Failed | Could not access |
| #45 | [Issue title] | ⏭️ Skipped | Already has plan |

### Summary
- **Planned:** 2
- **Failed:** 1
- **Skipped:** 1
```
