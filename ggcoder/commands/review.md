---
name: review
description: Run comprehensive code review using specialized reviewers
arguments:
  - name: target
    description: PR number, branch, or file paths
    required: false
---

# GGCoder Review

Run parallel review using specialized agents.

## Usage

```
/review               # Review current branch
/review 1234          # Review PR #1234
/review feature-x     # Review branch
```

## Process

Dispatches in parallel:
1. **Safety Reviewer** - Critical/High issues
2. **Quality Reviewer** - Medium/Low issues
3. **Testing Reviewer** - Test quality
4. **C++ Reviewer** - If .cpp/.h/.cmake/.sh files
5. **Build Reviewer** - If build files changed

Results sorted by severity: CRITICAL -> HIGH -> MEDIUM -> LOW

## After Review

Fix issues with:
```
/fix safety
/fix quality
/fix tests
```
