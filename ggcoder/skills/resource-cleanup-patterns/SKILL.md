---
name: resource-cleanup-patterns
description: Use when reviewing or fixing resource management - memory leaks, close() methods, try-finally, AutoCloseable in GridGain/Ignite code
---

# Resource Cleanup Patterns for GridGain/Ignite

## Critical Rules (from CODE_REVIEW_GUIDELINES.md)

### Rule 2: Resource Leak Detection
**Severity**: Critical | **Confidence Threshold**: 80%

**Triggers**:
- Buffers not released after use
- Resources held after close() called
- Non-idempotent close() methods

---

## Pattern 1: Idempotent Close with Guard

```java
private volatile boolean closeGuard = false;

@Override
public void close() {
    if (closeGuard) return;  // Already closed

    synchronized (this) {
        if (closeGuard) return;
        closeGuard = true;
    }

    if (delegate != null) {
        delegate.close();
    }
}
```

---

## Pattern 2: AutoCloseable Delegation

```java
@Override
public void close() throws Exception {
    if (delegate instanceof AutoCloseable) {
        ((AutoCloseable) delegate).close();
    }
}
```

---

## Pattern 3: Async Close with CompletableFuture

```java
private final CompletableFuture<Void> cancelFut = new CompletableFuture<>();
private volatile boolean cancelled = false;

@Override
public CompletableFuture<Void> closeAsync() {
    if (!cancelled) {
        synchronized (lock) {
            if (!cancelled) {
                // Complete pending operations
                if (!pendingOp.isDone()) {
                    pendingOp.completeExceptionally(new ClosedException());
                }

                // Close resources async
                resourceFut.whenCompleteAsync((resource, error) -> {
                    try {
                        if (resource instanceof AutoCloseable) {
                            ((AutoCloseable) resource).close();
                        }
                        cancelFut.complete(null);
                    } catch (Exception e) {
                        cancelFut.completeExceptionally(e);
                    }
                }, exec);

                cancelled = true;
            }
        }
    }
    return cancelFut.thenApply(Function.identity());  // Return NEW future
}
```

---

## Pattern 4: Release Last Fetched Data (from PR #3572)

```java
public boolean hasNext() {
    if (nativeCursor == null) return false;

    boolean hasMore = nativeCursor.hasNext();
    if (!hasMore) {
        lastRows = null;  // Release memory early
        closeNativeCursor();
    }
    return hasMore;
}
```

---

## Review Checklist

- [ ] close() is idempotent
- [ ] close() handles null delegates
- [ ] try-finally for context restoration
- [ ] Large objects released when exhausted (not just on close)
- [ ] closeAsync() returns new future, not internal one

## Fix Templates

### Making Close Idempotent
```java
// Before
public void close() { resource.close(); }

// After
private volatile boolean closed = false;
public void close() {
    if (closed) return;
    synchronized (this) {
        if (closed) return;
        closed = true;
    }
    if (resource != null) resource.close();
}
```
