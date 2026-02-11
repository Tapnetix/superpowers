---
name: pr-review
description: Review a PR using all specialized reviewers and fixers in parallel
arguments:
  - name: target
    description: "PR number, branch name, or 'current' for current branch (default: current)"
    required: false
---

# PR Review (Full Review + Fix)

Review a pull request using all specialized gg-* reviewers in parallel, then dispatch fixers for any findings.

## Usage

```
/pr-review              # Review current branch vs main
/pr-review 1234         # Review PR #1234
/pr-review feature-x    # Review branch feature-x vs main
```

## Step-by-Step Process

**You MUST follow these steps exactly. Do NOT skip any step.**

### Step 1: Get the PR Diff

**For current branch (default):**
```bash
# Find the base branch
BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
git diff "${BASE_BRANCH}...HEAD" --name-only
git diff "${BASE_BRANCH}...HEAD"
```

**For a PR number:**
```bash
gh pr diff {NUMBER}
gh pr diff {NUMBER} --name-only
```

**For a branch name:**
```bash
BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
git diff "${BASE_BRANCH}...{BRANCH}" --name-only
git diff "${BASE_BRANCH}...{BRANCH}"
```

If there are no changes, tell the user and stop.

### Step 2: Determine Which Reviewers to Dispatch

Based on the changed files, select ALL applicable reviewers:

| Changed File Types | Reviewers to Dispatch |
|---|---|
| `.java`, `.cs` | `gg-safety-reviewer`, `gg-quality-reviewer`, `gg-testing-reviewer` |
| `.cpp`, `.h` | `gg-cpp-reviewer` |
| `.cmake`, `.sh` | `gg-cpp-reviewer` |
| `build.gradle`, `pom.xml`, `CMakeLists.txt`, `settings.gradle` | `gg-build-reviewer` |

**If no file type matches any specific reviewer, still dispatch `gg-quality-reviewer` as a baseline.**

### Step 3: Dispatch ALL Reviewers in Parallel

Use the **Task tool** to dispatch each reviewer as a subagent. **All reviewers MUST be dispatched in a single message** so they run in parallel.

For each reviewer, use this prompt template:

```
Review the following PR changes for issues in your domain.

PR changed files:
{LIST_OF_CHANGED_FILES}

Full diff:
```diff
{THE_FULL_DIFF}
```

Focus on your specialty area. Report issues using this format:

### [SEVERITY] Issue Title
**File**: `path/File.java:line`
**Confidence**: N%
**Problem**: Description
**Suggested Fix**: Code or explanation

Only report issues with confidence >= 80% for Critical, >= 85% for High.
If the code is clean in your domain, explicitly say "No issues found."
```

**Subagent types to use:**
- `ggcoder:gg-safety-reviewer`
- `ggcoder:gg-quality-reviewer`
- `ggcoder:gg-testing-reviewer`
- `ggcoder:gg-cpp-reviewer`
- `ggcoder:gg-build-reviewer`

### Step 4: Aggregate Review Results

After all reviewers return:

1. **Collect all findings** from each reviewer
2. **Sort by severity**: CRITICAL > HIGH > MEDIUM > LOW
3. **Deduplicate**: If two reviewers flag the same issue, keep the higher-confidence one
4. **Present to user** as an organized report

### Step 5: Dispatch Fixers in Parallel

If there are CRITICAL or HIGH findings, **automatically dispatch fixers** for each category that had findings:

| Review Category | Fixer to Dispatch |
|---|---|
| Safety findings (concurrency, resources, null) | `gg-safety-fixer` |
| Quality findings (dead code, duplication, style) | `gg-quality-fixer` |
| Testing findings (coverage, assertions, flakiness) | `gg-test-fixer` |
| Documentation findings (typos, Javadoc) | `gg-doc-fixer` |
| C++ findings (headers, ownership) | `gg-cpp-fixer` |
| Build findings (dependencies, config) | `gg-build-fixer` |

For each fixer, use this prompt template:

```
Fix the following issues found during code review.

Review findings for your domain:
{FINDINGS_FOR_THIS_CATEGORY}

Workflow:
1. Read each finding
2. Load relevant pattern skills
3. Write a failing test for the bug (if applicable)
4. Apply fix using skill patterns
5. Verify the test passes
6. Report what you fixed

Changed files in this PR:
{LIST_OF_CHANGED_FILES}
```

**Subagent types to use:**
- `ggcoder:gg-safety-fixer`
- `ggcoder:gg-quality-fixer`
- `ggcoder:gg-test-fixer`
- `ggcoder:gg-doc-fixer`
- `ggcoder:gg-cpp-fixer`
- `ggcoder:gg-build-fixer`

**Dispatch ALL applicable fixers in a single message** so they run in parallel.

### Step 6: Architecture Review

After fixers complete, dispatch `code-reviewer` for architecture-level review:

```
Review the implementation in this PR for architecture and design quality.

What was implemented: {SUMMARY_OF_PR_CHANGES}
Changed files: {LIST_OF_CHANGED_FILES}

Full diff:
```diff
{THE_FULL_DIFF}
```

Focus on:
1. Architecture and design patterns
2. Code organization and maintainability
3. Integration with existing systems
4. Any remaining issues after domain-specific fixes

Provide structured feedback with:
- Strengths
- Critical issues (must fix)
- Important issues (should fix)
- Suggestions (nice to have)
- Assessment: Ready to merge? Yes/No/With fixes
```

Use subagent type: `ggcoder:code-reviewer`

### Step 7: Final Report

Present a summary:

```markdown
## PR Review Complete

### Findings Summary
- Critical: N (fixed: M)
- High: N (fixed: M)
- Medium: N
- Low: N

### Fixes Applied
- [List of fixes applied by fixers]

### Architecture Assessment
[Summary from code-reviewer]

### Verdict
[Ready to merge / Needs attention / Not ready]
```

## Example

```
User: /pr-review

You: Reviewing current branch against main...

[Get diff, identify .java files changed]
[Dispatch in parallel: gg-safety-reviewer, gg-quality-reviewer, gg-testing-reviewer]

## Review Findings

### CRITICAL
- Non-thread-safe HashMap (CacheManager.java:15) - 95% confidence

### HIGH
- Missing null check (CacheManager.java:22) - 88% confidence
- Missing concurrent test (CacheManagerTest.java) - 90% confidence

[Dispatch fixers in parallel: gg-safety-fixer, gg-test-fixer]
[Dispatch code-reviewer for architecture review]

## PR Review Complete

### Findings Summary
- Critical: 1 (fixed: 1)
- High: 2 (fixed: 2)
- Medium: 0
- Low: 0

### Fixes Applied
- gg-safety-fixer: Replaced HashMap with ConcurrentHashMap, added null check
- gg-test-fixer: Added multi-threaded test case

### Architecture Assessment
Clean design, good separation of concerns. Ready to merge.

### Verdict: Ready to merge (after fixes committed)
```
