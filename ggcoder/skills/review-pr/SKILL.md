---
name: review-pr
description: Use when performing comprehensive PR review - orchestrates specialized reviewers
---

# PR Review Orchestration

## Process

1. **Fetch PR diff** - Get changed files
2. **Route to reviewers** based on file types:
   - `.java`, `.cs` → Safety + Quality + Testing
   - `.cpp`, `.h`, `.cmake`, `.sh` → C++
   - `build.gradle`, `CMakeLists.txt` → Build
3. **Run reviewers in parallel**
4. **Aggregate results** by severity

## Reviewer Dispatch

```
IF changed_files contain .java OR .cs:
    → Safety, Quality, Testing reviewers

IF changed_files contain .cpp OR .h OR .cmake:
    → C++ reviewer

IF changed_files contain build.gradle OR CMakeLists.txt:
    → Build reviewer
```

## Output Format

Sort findings:
1. CRITICAL - Must fix
2. HIGH - Should fix
3. MEDIUM - Recommended
4. LOW - Nice to have

Deduplicate across reviewers.
