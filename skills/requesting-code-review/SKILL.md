---
name: requesting-code-review
description: Use when completing tasks, implementing major features, or before merging to verify work meets requirements
---

# Requesting Code Review

Use layered review to catch domain-specific and architectural issues.

**Core principle:** Review early, review often, with specialized reviewers.

## When to Request Review

**Mandatory:**
- After each task in subagent-driven development
- After completing major feature
- Before merge to main

**Optional but valuable:**
- When stuck (fresh perspective)
- Before refactoring (baseline check)
- After fixing complex bug

## How to Request (Layered Review)

**1. Get git SHAs and changed files:**
```bash
BASE_SHA=$(git rev-parse HEAD~1)  # or origin/main
HEAD_SHA=$(git rev-parse HEAD)
git diff --name-only $BASE_SHA $HEAD_SHA
```

**2. Pass 1: GridGain Domain Reviewers (Parallel)**

Dispatch based on file types:

| File Type | Reviewers to Dispatch |
|-----------|----------------------|
| .java, .cs | gg-safety-reviewer, gg-quality-reviewer, gg-testing-reviewer |
| .cpp, .h, .cmake, .sh | gg-cpp-reviewer |
| build.gradle, CMakeLists.txt | gg-build-reviewer |

**3. Pass 2: Architecture Review**

After domain issues fixed, dispatch `ggcoder:code-reviewer`:

Use Task tool with ggcoder:code-reviewer type, fill template at `code-reviewer.md`

**Placeholders:**
- `{WHAT_WAS_IMPLEMENTED}` - What you just built
- `{PLAN_OR_REQUIREMENTS}` - What it should do
- `{BASE_SHA}` - Starting commit
- `{HEAD_SHA}` - Ending commit
- `{DESCRIPTION}` - Brief summary

**4. Act on feedback:**
- Fix Critical issues immediately
- Fix Important issues before proceeding
- Note Minor issues for later
- Push back if reviewer is wrong (with reasoning)

## Example

```
[Just completed Task 2: Add cache invalidation in Java]

You: Let me request layered code review before proceeding.

BASE_SHA=$(git log --oneline | grep "Task 1" | head -1 | awk '{print $1}')
HEAD_SHA=$(git rev-parse HEAD)

# Check changed files
git diff --name-only $BASE_SHA $HEAD_SHA
→ src/main/java/CacheManager.java
→ src/test/java/CacheManagerTest.java

# Pass 1: GridGain Domain Reviewers (parallel for .java files)
[Dispatch gg-safety-reviewer, gg-quality-reviewer, gg-testing-reviewer in parallel]

gg-safety-reviewer returns:
  [HIGH] Missing volatile on sharedCache field
  Confidence: 92%

gg-quality-reviewer returns:
  [MEDIUM] Magic number 300 for timeout
  Confidence: 90%

gg-testing-reviewer returns:
  [HIGH] Missing async variant test for invalidateAsync()
  Confidence: 88%

You: [Fix volatile, extract constant, add async test]

# Pass 2: Architecture Review
[Dispatch ggcoder:code-reviewer subagent]
  WHAT_WAS_IMPLEMENTED: Cache invalidation with TTL support
  PLAN_OR_REQUIREMENTS: Task 2 from docs/plans/cache-plan.md
  BASE_SHA: a7981ec
  HEAD_SHA: 3df7661

[Subagent returns]:
  Strengths: Clean architecture, good test coverage now
  Issues: None after domain fixes
  Assessment: Ready to proceed

[Continue to Task 3]
```

## Integration with Workflows

**Subagent-Driven Development:**
- Review after EACH task
- Catch issues before they compound
- Fix before moving to next task

**Executing Plans:**
- Review after each batch (3 tasks)
- Get feedback, apply, continue

**Ad-Hoc Development:**
- Review before merge
- Review when stuck

## Red Flags

**Never:**
- Skip review because "it's simple"
- Ignore Critical issues
- Proceed with unfixed Important issues
- Argue with valid technical feedback

**If reviewer wrong:**
- Push back with technical reasoning
- Show code/tests that prove it works
- Request clarification

See template at: requesting-code-review/code-reviewer.md
