---
name: version-compatibility-patterns
description: Use when adding features that need backward compatibility - protocol feature flags, version checks
---

# Version Compatibility Patterns for GridGain/Ignite

## From GridGain-9 PR Mining

Key pattern from PRs #3588, #3603, #3627.

## Pattern 1: Protocol Feature Flags

```java
public static final ClientProtocolFeature CQ_LONG_POLLING_WAIT_TIME =
    new ClientProtocolFeature(42);

public void serialize(PayloadWriter w, ProtocolVersion v) {
    if (v.supports(CQ_LONG_POLLING_WAIT_TIME)) {
        w.writeLong(longPollingWaitTimeMs);
    }
}
```

## Pattern 2: Compatibility Tests

Add tests for each supported version:

```java
@ParameterizedTest
@ValueSource(strings = {"9.1.17", "9.1.18", "9.2.0"})
void testCompatibility(String version) {
    // Test with specific version
}
```

## Checklist

- [ ] New protocol fields have feature flags
- [ ] Version check before using new features
- [ ] Compatibility tests for each version
- [ ] Version lists updated in release
