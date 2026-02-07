---
name: fix
description: Fix issues identified by review using specialized fixers
arguments:
  - name: category
    description: Category to fix (safety, quality, tests, docs, cpp, build)
    required: true
---

# GGCoder Fix

Apply fixes for review findings.

## Usage

```
/fix safety    # Fix concurrency, resources, null issues
/fix quality   # Fix dead code, duplication
/fix tests     # Fix test coverage, assertions
/fix docs      # Fix typos, Javadoc
/fix cpp       # Fix C++ headers, ownership
/fix build     # Fix dependencies, configs
```

## Workflow

Each fixer:
1. Reads review findings
2. Loads relevant skills
3. Applies TDD: write test -> fix -> verify
4. Commits when verified
