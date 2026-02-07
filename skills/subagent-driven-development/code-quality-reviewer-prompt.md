# Code Quality Reviewer Prompt Template

Use this template when dispatching code quality reviewer subagents.

**Purpose:** Verify implementation is well-built (clean, tested, maintainable)

**Only dispatch after spec compliance review passes.**

## Layered Review Process

### Pass 1: GridGain Domain Reviewers (Parallel)

Dispatch based on changed file types:

```
For .java/.cs files → dispatch in parallel:
  - ggcoder:gg-safety-reviewer (concurrency, resources, null safety)
  - ggcoder:gg-quality-reviewer (dead code, duplication, style)
  - ggcoder:gg-testing-reviewer (if test files changed)

For .cpp/.h/.cmake/.sh files:
  - ggcoder:gg-cpp-reviewer

For build.gradle/CMakeLists.txt:
  - ggcoder:gg-build-reviewer
```

### Pass 2: Architecture Review (Sequential)

After domain issues addressed:

```
Task tool (ggcoder:code-reviewer):
  Use template at requesting-code-review/code-reviewer.md

  WHAT_WAS_IMPLEMENTED: [from implementer's report]
  PLAN_OR_REQUIREMENTS: Task N from [plan-file]
  BASE_SHA: [commit before task]
  HEAD_SHA: [current commit]
  DESCRIPTION: [task summary]
```

**Returns:** Strengths, Issues (Critical/Important/Minor), Assessment

## Quick Reference

| File Type | Reviewers |
|-----------|-----------|
| .java, .cs | gg-safety, gg-quality, gg-testing, then code-reviewer |
| .cpp, .h | gg-cpp, then code-reviewer |
| build.gradle | gg-build, then code-reviewer |
| Other | code-reviewer only |
