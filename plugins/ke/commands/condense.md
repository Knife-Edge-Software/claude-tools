---
description: Consolidate issue into requirements description and implementation comment
---

# Condense Issue

Clean up a GitHub issue by consolidating all information into a clear requirements description and a single implementation comment. Removes noise and creates a definitive source of truth.

## Usage

```
/ke:condense <issue-number> [--dry-run]
```

- Use `--dry-run` to preview the condensed version without updating the issue

## Instructions

You are tasked with consolidating a GitHub issue into two essential parts:
1. **Issue Description** (Requirements) - What problem needs to be solved and acceptance criteria
2. **Single Comment** (Implementation) - How to solve it, marked with "## Implementation Plan"

The goal is to create a clean, authoritative specification by merging all discussion, decisions, and refinements into these two sections.

### Step 1: Parse Arguments and Fetch the Full Issue

**Parse arguments:**
- Check for `--dry-run` flag
- Extract issue number

**If `--dry-run` is present:**
- Generate condensed version but DO NOT update the issue
- Save output to local files: `.claude/condense-<issue-number>-description.md` and `.claude/condense-<issue-number>-plan.md`
- Show preview and ask if user wants to apply changes

**Fetch the full issue:**

Get the issue with all comments:

```bash
gh issue view <issue-number> --comments --json number,title,body,comments
```

Parse the output to extract:
- Current issue body
- All comments (author, timestamp, body)
- Comment IDs for deletion later

### Step 2: Analyze and Categorize Content

Read through the issue body and all comments. Categorize each piece of information:

**Requirements Information:**
- Problem statement / motivation
- User stories or use cases
- Acceptance criteria
- Functional requirements
- Non-functional requirements (performance, security, etc.)
- UI/UX specifications
- Constraints or limitations
- Success metrics
- Dependencies on other issues

**Implementation Information:**
- Technical approach or architecture
- Files to modify
- Step-by-step implementation plan
- Code patterns to follow
- API signatures
- Database schema changes
- Test requirements
- Edge cases to handle
- Error handling approach

**Images and Attachments:**
- Screenshots (especially for UI issues)
- Mockups and diagrams
- Architecture diagrams
- Error screenshots
- Other visual assets

**Detect images in markdown:**
```
![alt text](url)
```

**Track each image:**
- Source (which comment or issue body)
- Context (what it demonstrates)
- Relevance (requirements or implementation)

**Preserve images by:**
- Re-embedding in appropriate section (requirements for mockups, implementation for architecture diagrams)
- Adding descriptive context: "Screenshot showing error state when authentication fails:"
- Maintaining original alt text and URLs

**Cross-References to Preserve:**
- Issue references (`#42`, `#43`, `Depends on #X`, `Blocked by #Y`)
- Pull request references (`PR #123`)
- Commit references (`commit abc1234`)
- External links (documentation, Figma designs, API specs, etc.)
- Repository paths (`owner/repo#123`)

**Handle cross-references:**
- Keep all issue/PR references intact in context
- Preserve dependency statements verbatim
- Include external resource links with descriptive text
- Example: "See [Figma mockup](url) for complete UI specification"

**Metadata/Discussion (exclude from consolidation):**
- Acknowledgments ("looks good", "thanks", etc.)
- Questions that were answered later
- Outdated information superseded by later comments
- Tangential discussions
- Debug information or investigation notes (unless relevant to implementation)

### Step 3: Apply Temporal Precedence

When multiple comments address the same topic:

**Rule: Later comments supersede earlier comments**

Example:
- Comment 1 (day 1): "Use REST API"
- Comment 2 (day 3): "Actually, let's use GraphQL instead"
- **Result:** Use GraphQL (later decision wins)

**Detect conflicts:**
Look for contradictions in later comments that might not be intentional supersession:

Example conflict:
- Comment 1: "Add `userId` field to User table"
- Comment 5: "Add `user_id` field to User table"
- **Conflict:** Are these the same (naming change) or two different fields?

### Step 4: Check for Conflicts

If you detect potential conflicts that aren't clearly resolved by temporal precedence, stop and ask the user:

```markdown
## Condensation Conflicts Detected

I found the following conflicts while consolidating issue #42:

### Conflict 1: Field naming inconsistency

**Earlier (Comment 1, 3 days ago):**
> Add `userId` field to User table (camelCase)

**Later (Comment 5, 1 day ago):**
> Add `user_id` field to User table (snake_case)

**Question:** Is this:
- A) The same field - use snake_case version (later supersedes)
- B) Two different fields - both should be added
- C) A mistake - use camelCase version (earlier is correct)

### Conflict 2: API approach

**Earlier (Comment 2, 4 days ago):**
> Implement using REST API with pagination

**Later (Comment 7, 2 hours ago):**
> Use GraphQL for flexible querying

**Later still (Comment 8, 1 hour ago):**
> Make sure we support pagination for large datasets

**Question:** Should we:
- A) Use GraphQL with pagination (combine both later points)
- B) Use REST with pagination (ignore GraphQL comment)
- C) Something else

---

Please respond with your choices (e.g., "1A, 2A") or provide clarification.
```

**Wait for user response before proceeding.**

### Step 5: Consolidate Requirements (Issue Description)

Create a new issue description that includes:

```markdown
# [Original Title]

## Problem

[Clear problem statement - what needs to be solved and why]

## Acceptance Criteria

- [ ] [Criterion 1]
- [ ] [Criterion 2]
- [ ] [Criterion 3]

## Requirements

### Functional
- [Requirement 1]
- [Requirement 2]

### Non-Functional
- [Performance/security/accessibility requirements]

### UI/UX Specifications
[If applicable - detailed UI behavior, mockups, accessibility needs]

**Mockups:**
![Login form mockup](url)
*Shows the login form with email/password fields and "Remember me" checkbox*

### Visual Assets
[If applicable - screenshots, diagrams that illustrate requirements]

## Dependencies

[If applicable]
- Depends on #X
- Blocked by #Y

## Related Resources

[If applicable - external links]
- [Figma Design](url)
- [API Documentation](url)
- Related to PR #123

## Success Metrics

[If applicable - how to measure success]

---

*Issue consolidated by `/ke:condense` on [date]*
*Backup saved to: `.claude/backup-issue-<number>-<timestamp>.json`*
```

**Key principles:**
- Be comprehensive - include all important requirements
- Be clear - resolve ambiguities using later decisions
- Be organized - group related information
- Be actionable - write as checklist where possible
- Preserve context - explain the "why" not just the "what"
- **Preserve all images** - re-embed with descriptive context
- **Preserve cross-references** - keep all issue/PR/external links intact

### Step 6: Consolidate Implementation (Single Comment)

Create a single implementation plan comment:

```markdown
## Implementation Plan

### Overview
[Brief description of technical approach]

### Architecture
[If applicable - include architecture diagrams from comments]
![Architecture diagram](url)
*Shows the flow between authentication middleware, session store, and user service*

### Files to Modify
- `path/to/file1.ts` - [what changes]
- `path/to/file2.ts` - [what changes]

### Step-by-Step

#### Step 1: [First major step]
[Detailed instructions]

**Files:** `file1.ts`, `file2.ts`

```typescript
// Example code structure
interface User {
  userId: string;
  // ...
}
```

**Testing:** [What to test at this step]

#### Step 2: [Second major step]
[Detailed instructions]

#### Step 3: [Third major step]
[Detailed instructions]

### Error Handling
- [Error scenario 1] → [How to handle]
- [Error scenario 2] → [How to handle]

### Edge Cases
- [Edge case 1] → [How to handle]
- [Edge case 2] → [How to handle]

### Testing Strategy
- Unit tests: [What to test]
- Integration tests: [What to test]
- Manual testing: [What to verify]

### Related Work
[If applicable]
- Builds on PR #120
- See commit abc1234 for similar pattern
- Related to issue #45

### Success Criteria

After implementation:
- [ ] All acceptance criteria from issue description are met
- [ ] All tests pass
- [ ] No console errors or warnings
- [ ] [Other verification steps]

---

*Implementation plan consolidated by `/ke:condense` on [date]*
```

**Key principles:**
- Be specific - exact file paths, function names, approaches
- Be sequential - clear order of operations
- Be complete - cover all aspects (happy path, errors, edge cases, tests)
- Reference the requirements - tie back to acceptance criteria
- Include examples - code snippets where helpful
- **Preserve architecture diagrams** - re-embed with context
- **Preserve cross-references** - link to related PRs, commits, issues

### Step 7: Create Backup

**IMPORTANT:** Before making any changes to the issue, create a backup of the original state.

```bash
# Create backup directory if it doesn't exist
mkdir -p .claude

# Fetch full issue data including all comments
gh issue view <issue-number> --comments --json number,title,body,comments,createdAt,updatedAt > .claude/backup-issue-<issue-number>-$(date +%Y%m%d-%H%M%S).json

# Store the backup file path for the summary report
BACKUP_FILE=".claude/backup-issue-<issue-number>-$(date +%Y%m%d-%H%M%S).json"
```

**Backup includes:**
- Original issue body
- All comments with authors and timestamps
- Comment IDs (for potential restoration)
- Metadata (created/updated timestamps)

**Display confirmation:**
```markdown
## Backup Created

Original issue saved to: `$BACKUP_FILE`

This backup can be used to restore the issue if needed using `/ke:condense --rollback <issue-number>`.
```

### Step 8: Preview or Apply Changes

**If `--dry-run` flag is present:**

Save the condensed versions to local files for review:

```bash
# Save condensed description
cat > .claude/condense-<issue-number>-description.md << 'EOF'
[Condensed description content]
EOF

# Save condensed implementation plan
cat > .claude/condense-<issue-number>-plan.md << 'EOF'
[Condensed implementation plan content]
EOF
```

**Display preview:**
```markdown
## Dry Run - Preview Generated

**Condensed description saved to:**
`.claude/condense-<issue-number>-description.md`

**Condensed implementation plan saved to:**
`.claude/condense-<issue-number>-plan.md`

**To review:**
```bash
cat .claude/condense-<issue-number>-description.md
cat .claude/condense-<issue-number>-plan.md
```

**To apply these changes:**
Run `/ke:condense <issue-number>` without the `--dry-run` flag.

**To manually apply:**
```bash
gh issue edit <issue-number> --body-file .claude/condense-<issue-number>-description.md
gh issue comment <issue-number> --body-file .claude/condense-<issue-number>-plan.md
```
```

**Stop here if dry-run mode. Do not update the issue.**

**If NOT dry-run mode, proceed with updating:**

### Step 9: Update the Issue

**Update the issue description:**

```bash
# Save new description to temp file
cat > /tmp/issue-description.md << 'EOF'
[New consolidated description]
EOF

# Update issue
gh issue edit <issue-number> --body-file /tmp/issue-description.md
```

**Add the implementation comment:**

```bash
# Save implementation to temp file
cat > /tmp/implementation-plan.md << 'EOF'
[New consolidated implementation plan]
EOF

# Add comment
gh issue comment <issue-number> --body-file /tmp/implementation-plan.md
```

### Step 10: Handle Old Comments (Ask User)

Present the user with options for old comments:

```markdown
## Old Comments

The issue now has a clean requirements description and implementation plan. The issue has 8 old comments that are now redundant.

**Options:**

**A) Leave old comments (default)**
- Preserves history and context
- Old comments remain visible but are superseded
- Easier to audit changes or undo if needed

**B) Add note to old comments**
- Add a comment at the top saying: "📝 This issue was consolidated on [date]. See the issue description and implementation plan comment for the current specification. Comments below are historical."
- Preserves history with clear guidance

**C) Delete old comments (destructive)**
- ⚠️ Cannot be undone
- Removes all historical context
- Only recommended if comments contain no valuable information

**D) Minimize specific comments**
- GitHub doesn't support hiding comments via API
- Would need to be done manually in the web UI

**Recommendation:** Option B (add note) provides the best balance of clarity and history preservation.

What would you like to do? (A/B/C)
```

**Wait for user choice.**

**If user chooses B:**

```bash
gh issue comment <issue-number> --body "📝 **This issue was consolidated on $(date +%Y-%m-%d).** See the issue description for requirements and the most recent comment for the implementation plan. Comments below are historical and superseded by the consolidated version."
```

**If user chooses C:**

```bash
# Get comment IDs (excluding the new implementation plan comment)
gh api repos/:owner/:repo/issues/<issue-number>/comments --jq '.[].id' | while read comment_id; do
  # Check if this is the new comment (skip it)
  # Delete old comments
  gh api -X DELETE repos/:owner/:repo/issues/comments/$comment_id
done
```

**Note:** Before deleting, show the list of comments that will be deleted and ask for final confirmation.

### Step 11: Generate Summary Report

```markdown
## Condensation Complete ✅

Issue #42 has been consolidated.

### Backup

**Original issue saved to:** `.claude/backup-issue-42-20260123-143000.json`

To restore the original issue if needed:
```bash
/ke:condense --rollback 42
```

### Changes Made

**Issue Description (Requirements)**
- Consolidated information from: original body, comments #2, #5, #7
- Added clear problem statement and acceptance criteria
- Organized requirements into functional/non-functional sections
- Preserved 2 mockup images from comments #5 and #7
- Preserved 3 cross-references to related issues (#45, #47) and external docs
- Total length: ~500 words

**Implementation Plan (Comment)**
- Consolidated information from: comments #3, #4, #6, #8, #9
- Created step-by-step implementation guide with 4 major steps
- Added error handling and edge case sections
- Added testing strategy
- Preserved 1 architecture diagram from comment #4
- Preserved cross-references to PR #120 and commit abc1234
- Total length: ~800 words

**Old Comments:** [Preserved with historical note / Deleted]

### Information Preserved
- ✅ All functional requirements
- ✅ All acceptance criteria
- ✅ Complete implementation approach
- ✅ Error handling specifications
- ✅ Testing requirements
- ✅ UI/UX specifications
- ✅ All images and diagrams (3 total)
- ✅ All cross-references (issues, PRs, commits, external links)

### Information Removed
- ❌ "Looks good" / "+1" comments (8 comments)
- ❌ Questions answered later in thread (2 questions)
- ❌ Superseded implementation approach (old REST approach replaced with GraphQL)

### Next Steps

1. Review the condensed issue: `gh issue view 42 --comments`
2. If everything looks correct, the issue is ready for `/ke:plan` or `/ke:branchfix`
3. If anything is missing, add it to the issue description or implementation comment
4. If you need to undo: `/ke:condense --rollback 42`

**Issue URL:** [GitHub URL]
```

### Important Guidelines

**What to preserve:**
- All unique requirements (functional and non-functional)
- All acceptance criteria
- Latest version of implementation decisions
- Important context about why certain approaches were chosen
- Dependencies and blockers
- Security, performance, accessibility requirements
- Edge cases and error scenarios
- **All images** (screenshots, mockups, diagrams) with descriptive context
- **All cross-references** (issues, PRs, commits, external links)

**What to exclude:**
- Social comments ("thanks", "LGTM", "+1")
- Superseded information (old decisions replaced by new ones)
- Questions that were answered (keep the answer, not the question)
- Debugging/investigation that led to a conclusion (keep conclusion, not debug process)
- Off-topic tangents
- Duplicate information

**When in doubt:**
- Preserve information rather than deleting it
- Ask the user if something seems important but contradictory
- Include rationale for technical decisions (the "why")
- Be explicit about what was superseded and why

**Error handling:**
- If `gh issue edit` fails, report the error and save the condensed version to local files for manual upload
- If unable to parse comments, ask user to check issue format
- If the issue is too complex (>50 comments), warn that manual review is recommended

### Rollback Functionality

To restore an issue to its original state:

```bash
/ke:condense --rollback <issue-number>
```

**Rollback process:**

1. Look for the most recent backup file in `.claude/backup-issue-<number>-*.json`
2. If multiple backups exist, show list and ask user which to restore (default: most recent)
3. Parse the backup JSON to extract:
   - Original issue body
   - All original comments with their content and order
4. **Warning:** Display what will be changed:
   ```markdown
   ## Rollback Issue #42

   This will restore the issue to its state from backup:
   **Backup:** `.claude/backup-issue-42-20260123-143000.json`
   **Backup date:** 2026-01-23 14:30:00

   **Current state:**
   - Issue body: 500 words (condensed format)
   - Comments: 1 (implementation plan)

   **After rollback:**
   - Issue body: 300 words (original format)
   - Comments: 12 (original comments restored)

   ⚠️ **Warning:** This will overwrite the current issue description. The current state will be backed up first.

   Proceed? (yes/no)
   ```

5. If user confirms, create a backup of the current state before rolling back
6. Restore the issue body from backup:
   ```bash
   # Extract original body from backup
   jq -r '.body' .claude/backup-issue-42-20260123-143000.json > /tmp/restore-body.md
   gh issue edit <issue-number> --body-file /tmp/restore-body.md
   ```

7. Note about comments:
   ```markdown
   **Note:** GitHub API does not support restoring deleted comments or changing comment order.

   **Options:**
   A) Leave current comments as-is (issue body restored, comments remain)
   B) Manually restore comments from backup (you'll need to copy/paste from backup file)

   **Backup file location:** `.claude/backup-issue-42-20260123-143000.json`

   To view original comments:
   ```bash
   jq -r '.comments[] | "---\n\(.author.login) at \(.createdAt):\n\(.body)\n"' .claude/backup-issue-42-20260123-143000.json
   ```
   ```

8. Generate rollback report:
   ```markdown
   ## Rollback Complete ✅

   Issue #42 has been restored to its original state from backup.

   **Restored from:** `.claude/backup-issue-42-20260123-143000.json`
   **Current state backed up to:** `.claude/backup-issue-42-20260123-150000.json`

   **Changes:**
   - Issue body: Restored to original (pre-condensation)
   - Comments: [Status of comments]

   **Next steps:**
   1. Review the restored issue: `gh issue view 42`
   2. If you want to condense again with different settings: `/ke:condense 42`
   ```

**Edge cases:**

**No backup found:**
```markdown
❌ No backup found for issue #42

Searched in: `.claude/backup-issue-42-*.json`

Cannot rollback without a backup. If you have a backup file elsewhere, you can manually restore using:

```bash
gh issue edit 42 --body-file <path-to-backup-body>
```
```

**Multiple backups:**
```markdown
## Multiple Backups Found for Issue #42

1. `.claude/backup-issue-42-20260123-143000.json` (2026-01-23 14:30) - before condensation
2. `.claude/backup-issue-42-20260123-150000.json` (2026-01-23 15:00) - before rollback
3. `.claude/backup-issue-42-20260124-100000.json` (2026-01-24 10:00) - before condensation

Which backup would you like to restore? (1-3, default: 1)
```

### Edge Cases

**Issue with no comments:**
```markdown
Issue #42 has no comments. The description appears complete.

**Options:**
A) Leave as-is (if description is clear and complete)
B) Reorganize description into standard format (problem/acceptance/requirements)
C) Add implementation plan comment (if missing)

What would you like to do?
```

**Issue with implementation already clean:**
```markdown
Issue #42 already has a clean structure:
- Clear requirements in description ✅
- Single implementation plan comment ✅
- No redundant comments ✅

No condensation needed. Issue is ready for implementation.
```

**Multiple implementation plan comments:**
```markdown
Found 3 comments labeled "Implementation Plan". Will consolidate them in chronological order, with later plans taking precedence.

Detected changes between plans:
- Plan 1 (3 days ago): REST API approach
- Plan 2 (2 days ago): GraphQL approach (supersedes Plan 1)
- Plan 3 (1 day ago): Adds pagination to GraphQL (extends Plan 2)

**Result:** Will use Plan 3 (GraphQL + pagination) as it's the latest evolution.

Proceed? (yes/no)
```

**Issue is locked or closed:**
```markdown
⚠️ Issue #42 is [closed/locked].

**Options:**
A) Skip condensation (issue is archived)
B) Reopen temporarily to condense, then close again
C) Create condensed version in local file for reference

What would you like to do?
```
