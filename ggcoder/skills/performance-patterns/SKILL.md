---
name: performance-patterns
description: Use when reviewing performance-related changes - benchmarking requirements, fast paths, simplification
---

# Performance Patterns for GridGain/Ignite

## From Ignite-3 PR Mining

Reviewers consistently request benchmark data.

## Pattern 1: Benchmark Requirements

For performance PRs, provide:
1. JMH microbenchmark results
2. Before/after comparison tables
3. Multiple configuration tests

## Pattern 2: Fast Paths

```java
// Add fast path for common case (from PR review)
public Object convert(Object val) {
    if (val instanceof Byte) {  // Fast path first
        return val;
    }
    // Slower generic path
    return genericConvert(val);
}
```

## Pattern 3: Remove Unnecessary Executor

From PR review:
> "We don't need any executor at all. It is just never used because we build synchronous cache underneath. You can pass Runnable::run instead."

```java
// Instead of dedicated executor for sync cache
new AsyncWrapper(future, Runnable::run);
```
