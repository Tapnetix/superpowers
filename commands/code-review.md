---
name: code-review
description: Review uncommitted code changes using all specialized reviewers in parallel
arguments:
  - name: scope
    description: "Scope of changes: 'staged' for staged only, 'all' for all uncommitted (default: all)"
    required: false
---

# Code Review (Uncommitted Changes)

Review your current uncommitted work using all specialized gg-* reviewers in parallel.

## Usage

```
/code-review           # Review all uncommitted changes
/code-review staged    # Review only staged changes
```

## Step-by-Step Process

**You MUST follow these steps exactly. Do NOT skip any step.**

### Step 1: Get the Diff

```bash
# For all uncommitted changes (default):
git diff HEAD

# For staged only:
git diff --cached
```

If there are no changes, tell the user and stop.

### Step 2: Get Changed File List

```bash
# For all uncommitted:
git diff HEAD --name-only

# For staged only:
git diff --cached --name-only
```

### Step 3: Determine Which Reviewers to Dispatch

Based on the changed files, select ALL applicable reviewers:

| Changed File Types | Reviewers to Dispatch |
|---|---|
| `.java`, `.cs` | `gg-safety-reviewer`, `gg-quality-reviewer`, `gg-testing-reviewer` |
| `.cpp`, `.h` | `gg-cpp-reviewer` |
| `.cmake`, `.sh` | `gg-cpp-reviewer` |
| `build.gradle`, `pom.xml`, `CMakeLists.txt`, `settings.gradle` | `gg-build-reviewer` |

**If no file type matches any specific reviewer, still dispatch `gg-quality-reviewer` as a baseline.**

### Step 4: Dispatch ALL Selected Reviewers in Parallel

Use the **Task tool** to dispatch each reviewer as a subagent. **All reviewers MUST be dispatched in a single message** so they run in parallel.

For each reviewer, use this prompt template:

```
Review the following code changes for issues in your domain.

Changed files:
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
```

**Subagent types to use:**
- `ggcoder:gg-safety-reviewer`
- `ggcoder:gg-quality-reviewer`
- `ggcoder:gg-testing-reviewer`
- `ggcoder:gg-cpp-reviewer`
- `ggcoder:gg-build-reviewer`

### Step 5: Aggregate Results

After all reviewers return:

1. **Collect all findings** from each reviewer
2. **Sort by severity**: CRITICAL > HIGH > MEDIUM > LOW
3. **Deduplicate**: If two reviewers flag the same issue, keep the higher-confidence one
4. **Present to user** in a single organized report

### Step 6: Offer Fixes

After presenting findings, offer to fix issues:

```
Found N issues. To fix:
/fix safety    # Fix concurrency, resource, null issues
/fix quality   # Fix dead code, duplication
/fix tests     # Fix test coverage, assertions
/fix docs      # Fix documentation issues
/fix cpp       # Fix C++ issues
/fix build     # Fix build config issues
```

## Example

```
User: /code-review

You: Let me review your uncommitted changes.

[Run git diff HEAD --name-only]
Changed files:
  src/main/java/CacheManager.java
  src/test/java/CacheManagerTest.java

[Dispatch in parallel: gg-safety-reviewer, gg-quality-reviewer, gg-testing-reviewer]

## Code Review Results

### CRITICAL
- **[CRITICAL] Non-thread-safe HashMap in concurrent context**
  File: `CacheManager.java:15`  |  Confidence: 95%
  Problem: HashMap accessed from multiple threads without synchronization
  Fix: Use ConcurrentHashMap

### HIGH
- **[HIGH] Missing null check on cache key**
  File: `CacheManager.java:22`  |  Confidence: 88%
  Fix: Add Objects.requireNonNull(key)

### MEDIUM
- **[MEDIUM] Missing test for concurrent access**
  File: `CacheManagerTest.java`  |  Confidence: 90%
  Fix: Add multi-threaded test case

Found 3 issues (1 Critical, 1 High, 1 Medium).
Use /fix safety to fix Critical/High safety issues.
```
