---
description: Review and refine issue specifications for quality and clarity
---

# Refine Issues

Review GitHub issues to ensure they are complete, well-scoped, internally consistent, and ready for implementation without improvisation.

## Usage

```
/ke:refine [issue-numbers] [--milestone <name>]
```

- With no arguments, analyzes all open issues
- With issue numbers (e.g., `/ke:refine 42 45 47`), analyzes only those issues
- Use `--milestone <name>` to filter to a specific milestone (e.g., `--milestone "Sprint 1"`)

## Instructions

You are tasked with reviewing GitHub issues to ensure they meet quality standards before implementation. The goal is to catch problems early so future Claude sessions can implement without improvisation.

### Step 1: Parse Arguments and Fetch Issues

**Parse arguments:**
1. Extract `--milestone <name>` flag if present (value may be quoted, e.g., `"Sprint 1"`)
2. Remaining arguments are treated as issue numbers

**If `--milestone` is provided:**
```bash
gh issue list --milestone "<name>" --state open --json number,title,body,labels --limit 100
```

**If specific issue numbers are provided:**
```bash
# For each issue number
gh issue view <issue-number> --json number,title,body,labels,comments
```

**If no arguments:**
```bash
gh issue list --state open --json number,title,body,labels --limit 100
```

### Step 2: Fetch Implementation Plans

For each issue, check for an implementation plan in the comments:

```bash
gh issue view <issue-number> --comments
```

Look for comments containing "## Implementation Plan" or similar plan markers. Extract the full plan text if present.

### Step 3: Analyze Each Issue

For each issue, evaluate against these criteria:

#### Criterion 1: Completeness (No Improvisation Required)

**Check for:**
- Clear acceptance criteria
- Specific file paths mentioned (when relevant)
- API signatures defined (when relevant)
- UI behavior specified in detail (when relevant)
- Error handling requirements
- Edge cases considered
- Test expectations defined

**Red flags:**
- Vague language like "improve", "enhance", "make better"
- Missing details about what success looks like
- No plan comment exists
- Plan says "TBD" or "to be determined"
- Ambiguous requirements that could be interpreted multiple ways

**Severity levels:**
- **Critical**: Cannot implement without guessing (e.g., no acceptance criteria)
- **Major**: Significant details missing (e.g., no error handling specified)
- **Minor**: Small gaps that could cause hesitation (e.g., unclear edge case)

#### Criterion 2: Scope (Context Window Fit)

**Estimate token count:**
- Issue body + plan comment + relevant code context
- Assume ~4 chars per token
- Typical context limit: ~180K tokens (720K chars)
- Safe implementation size: <50K tokens (200K chars of context)

**Check for:**
- Number of files to modify (>10 files is a warning)
- Complexity of changes (full rewrites vs small edits)
- Amount of context needed to understand the change

**Red flags:**
- "Refactor entire module"
- "Rewrite authentication system"
- Long list of files (>10)
- Multiple subsystems involved
- Requires understanding large amounts of existing code

**Severity levels:**
- **Critical**: Clearly too large (estimated >100K tokens)
- **Major**: Likely too large (estimated 50-100K tokens)
- **Minor**: On the edge (estimated 40-50K tokens)

**Suggestions for splitting:**
- Identify natural seams (separate features, layers, files)
- Propose split into 2-4 smaller issues

#### Criterion 3: Internal Consistency (No Self-Contradiction)

**Check for:**
- Contradictions between issue body and plan
- Contradictions within the plan steps
- Acceptance criteria that conflict with each other
- Requirements that are mutually exclusive

**Red flags:**
- "Do X" in one section, "Don't do X" in another
- Two different approaches mentioned without choosing one
- Acceptance criteria that can't all be true simultaneously
- Technical constraints that conflict

**Severity levels:**
- **Critical**: Direct contradiction (e.g., "use REST" vs "use GraphQL")
- **Major**: Conflicting approaches mentioned
- **Minor**: Ambiguous phrasing that could be read as conflicting

#### Criterion 4: External Consistency (No Cross-Issue Conflicts)

**Check for:**
- Same file modified by multiple issues in different ways
- API signatures that conflict between issues
- UI changes that would clash
- Database schema changes that conflict
- Dependencies that create circular references

**Red flags:**
- Issue A adds field `user_id`, Issue B renames it to `userId`
- Issue A uses pattern X, Issue B uses pattern Y for the same thing
- Issue A and B both modify the same function incompatibly
- Dependency cycle detected (A depends on B, B depends on A)

**Severity levels:**
- **Critical**: Direct conflict (both issues can't be implemented as specified)
- **Major**: Likely conflict (implementation would require coordination)
- **Minor**: Potential conflict (might work but seems risky)

#### Criterion 5: Cohesion and Coupling

**Check for:**
- Single Responsibility: Does issue do one thing?
- Independence: Can it be implemented without other issues?
- Coupling: Does it depend on many other issues?
- Fragmentation: Is it too small to be worth tracking separately?

**Red flags:**
- Issue title has "and" multiple times (e.g., "Add login and logout and password reset")
- Issue touches >5 unrelated subsystems
- Issue is blocked by >3 other issues
- Issue is trivial (1-line change) and could be batched

**Severity levels:**
- **Critical**: Doing 5+ unrelated things, or completely blocked by many issues
- **Major**: Doing 2-3 loosely related things, or blocked by 2-3 issues
- **Minor**: Could be split but isn't terrible, or has 1 dependency

**Suggestions:**
- Split multi-responsibility issues
- Merge trivial issues into batches
- Identify and document necessary dependencies

#### Criterion 6: User Experience Quality

**Only applies to issues with UI changes.**

**Check for:**
- Accessibility requirements (keyboard nav, screen readers, ARIA)
- Responsive design considerations (mobile, tablet, desktop)
- Loading states and error states defined
- User feedback mechanisms (toasts, messages, validation)
- Consistency with existing UI patterns
- Performance considerations (debouncing, throttling, lazy loading)
- Empty states handled ("no data" scenarios)

**Red flags:**
- No loading state specified
- No error handling UI
- No mobile considerations
- Inconsistent with existing UI patterns
- Missing accessibility requirements
- No empty state handling

**Common UX expectations:**
- Buttons show loading spinners during async operations
- Forms validate on blur/submit and show clear error messages
- Navigation is keyboard accessible
- Colors meet WCAG contrast requirements
- Mobile UI is touch-friendly (44px min touch targets)
- Success/error feedback is immediate and clear

**Severity levels:**
- **Critical**: Missing essential UX (e.g., no error handling at all)
- **Major**: Missing important UX (e.g., no loading states)
- **Minor**: Missing polish (e.g., no empty state message)

### Step 4: Check Dependencies

Read dependencies from issue bodies (look for "Depends on #X" or "Blocked by #X"):

```bash
gh issue view <issue-number> --json body | grep -E "(Depends on|Blocked by) #[0-9]+"
```

Cross-reference with the issues being analyzed to catch circular dependencies or contradictions.

### Step 5: Generate Report

Output a structured report with this format:

```markdown
# Issue Refinement Report

Analyzed <N> issues. Found <X> critical, <Y> major, <Z> minor concerns.

---

## Issue #42: Add authentication middleware

**Status:** 🔴 Needs revision (2 critical, 1 major, 2 minor concerns)

### Critical Concerns

#### 1. Completeness: No error handling specified
**Problem:** The plan doesn't specify what should happen when authentication fails. Should it return 401? Redirect? Show an error page?

**Impact:** Implementation will require guessing. Different sessions might handle this differently, leading to inconsistent behavior.

**Suggestion:**
- Add acceptance criteria for authentication failure scenarios
- Specify HTTP status codes to return
- Define error response format
- Consider rate limiting for failed attempts

#### 2. External Consistency: Conflicts with Issue #45
**Problem:** This issue uses session-based auth, but issue #45 implements JWT tokens. Both approaches are specified without a clear choice.

**Impact:** Cannot implement both as specified. Need to choose one approach.

**Suggestion:**
- Choose one authentication strategy (sessions or JWT)
- Update both issues to use the chosen approach
- Consider splitting into two alternatives if both are needed

### Major Concerns

#### 3. Scope: Touches many files
**Problem:** Plan mentions modifying 12 files across authentication, authorization, and session management. This is a large surface area.

**Impact:** May exceed context window or require multiple sessions. Increases risk of incomplete implementation.

**Suggestion:**
- Split into smaller issues:
  - Issue 42a: Add basic auth middleware (core only)
  - Issue 42b: Add session management
  - Issue 42c: Add authorization checks
- Establish clear boundaries between issues

### Minor Concerns

#### 4. UX: No loading state for login form
**Problem:** Plan doesn't specify a loading spinner or disabled state during authentication.

**Impact:** User might click "Login" multiple times, causing duplicate requests.

**Suggestion:**
- Add loading spinner to login button during authentication
- Disable form fields during submission
- Show error message if authentication fails

#### 5. Cohesion: Combines authentication and authorization
**Problem:** Issue title says "authentication" but plan includes authorization checks (role-based access).

**Impact:** Slightly unfocused, but not terrible.

**Suggestion:**
- Consider splitting authorization into separate issue
- Or update title to "Add auth middleware" (covers both)

---

## Issue #45: Add login endpoint

**Status:** 🟡 Minor revisions suggested (0 critical, 0 major, 2 minor concerns)

### Minor Concerns

#### 1. External Consistency: Auth approach conflicts with Issue #42
**Problem:** Specifies JWT tokens, but Issue #42 uses sessions.

**Impact:** See Issue #42 concern #2.

**Suggestion:** See Issue #42.

#### 2. Completeness: Edge case not specified
**Problem:** Doesn't specify behavior when user is already logged in.

**Impact:** Minor - implementation will likely handle this reasonably.

**Suggestion:**
- Add acceptance criterion: "If user is already authenticated, return existing token/session"

---

## Issue #51: Fix typo in README

**Status:** 🟢 Ready to implement (0 concerns)

No concerns found. Issue is clear, scoped, and ready for implementation.

---

## Summary

### By Severity
- **Critical:** 4 concerns across 2 issues (must fix before implementation)
- **Major:** 3 concerns across 2 issues (should fix before implementation)
- **Minor:** 6 concerns across 3 issues (nice to fix)

### By Issue Status
- **🔴 Needs revision:** 2 issues (#42, #48)
- **🟡 Minor revisions:** 2 issues (#45, #47)
- **🟢 Ready:** 3 issues (#51, #52, #53)

### Cross-Cutting Concerns
1. **Authentication approach inconsistency** (Issues #42, #45, #47)
   - Decision needed: Sessions vs JWT
   - Affects 3 issues
   - Should be resolved before implementing any of them

2. **File coupling** (Issues #42, #45)
   - Both modify `src/auth/middleware.ts`
   - Consider implementing sequentially or coordinating changes

### Recommendations

#### High Priority (Do First)
1. **Resolve auth approach inconsistency** - Update #42, #45, #47 to use one approach
2. **Split Issue #42** - Too large, split into 3 smaller issues
3. **Fix Issue #48 contradictions** - Plan conflicts with issue body

#### Medium Priority (Should Do)
4. **Add error handling to #42** - Specify failure scenarios
5. **Add loading states to #45** - Improve UX
6. **Document #47 dependencies** - Currently implicit

#### Low Priority (Nice to Have)
7. **Merge trivial issues** - #51, #52, #53 could be one issue
8. **Add mobile specs to #47** - Currently desktop-only

---

## Next Steps

1. Address critical concerns (required before implementation)
2. Update affected issues with suggested changes
3. Re-run `/ke:refine` after updates to verify improvements
4. Use `/ke:map` to regenerate execution plan with refined issues
```

### Step 6: Provide Actionable Summaries

For each issue with concerns, provide a checklist the user can copy into the issue:

```markdown
---

## Suggested Issue Updates

### Issue #42

Copy this checklist into a new comment on issue #42:

**Refinement Checklist:**
- [ ] Specify error handling for authentication failures (status codes, response format)
- [ ] Choose authentication strategy (sessions vs JWT) and update plan
- [ ] Consider splitting into smaller issues (auth core, sessions, authorization)
- [ ] Add loading state specification for login form
- [ ] Add acceptance criteria for edge cases (already logged in, concurrent logins)

### Issue #45

Copy this checklist into a new comment on issue #45:

**Refinement Checklist:**
- [ ] Align with authentication strategy chosen in Issue #42
- [ ] Add acceptance criterion for "already logged in" scenario
```

### Important

- DO NOT implement any code changes
- DO NOT modify issues automatically - only provide recommendations
- Focus on preventing future problems, not nitpicking
- Be specific in suggestions (actionable, not vague)
- Consider the implementation context (what Claude will need to know)
- Prioritize concerns by severity (critical > major > minor)
- Group cross-cutting concerns that affect multiple issues
- Provide concrete examples in suggestions when helpful
- If issues look good, say so clearly (don't manufacture problems)
- The goal is to make implementation smooth, not to achieve perfection

### Edge Cases

**No issues found:**
```markdown
# Issue Refinement Report

No open issues found matching the specified criteria.
```

**All issues are ready:**
```markdown
# Issue Refinement Report

Analyzed 5 issues. All issues are ready to implement! 🎉

No critical or major concerns found. The issue set is:
- Complete (minimal improvisation needed)
- Well-scoped (fits in context window)
- Internally consistent (no contradictions)
- Externally consistent (no conflicts between issues)
- Well-organized (focused and independent)
- UX-ready (all UI specs are clear)

Proceed with implementation using `/ke:map` or `/ke:branchfix`.
```

**Rate limiting:**
If analyzing many issues (>20), add a note:
```markdown
*Note: Analyzed 35 issues. This is a large set and some subtle conflicts may be missed. Consider reviewing in smaller batches for thorough analysis.*
```
