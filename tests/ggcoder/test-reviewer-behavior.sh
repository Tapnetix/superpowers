#!/usr/bin/env bash
# Behavioral tests for ggcoder reviewers
# Tests reviewer agent behavior with real code scenarios
# Uses subagent pressure testing methodology from writing-skills

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Cross-platform timeout function (works on macOS without coreutils)
run_with_timeout() {
    local timeout_seconds="$1"
    shift

    if command -v timeout &> /dev/null; then
        timeout "$timeout_seconds" "$@"
        return $?
    elif command -v gtimeout &> /dev/null; then
        gtimeout "$timeout_seconds" "$@"
        return $?
    else
        "$@"
        return $?
    fi
}

# Source test helpers if available
if [ -f "$SCRIPT_DIR/../claude-code/test-helpers.sh" ]; then
    source "$SCRIPT_DIR/../claude-code/test-helpers.sh"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

passed=0
failed=0
skipped=0

pass() {
    echo -e "  ${GREEN}[PASS]${NC} $1"
    passed=$((passed + 1))
}

fail() {
    echo -e "  ${RED}[FAIL]${NC} $1"
    echo "        $2"
    failed=$((failed + 1))
}

skip() {
    echo -e "  ${YELLOW}[SKIP]${NC} $1"
    skipped=$((skipped + 1))
}

info() {
    echo -e "${YELLOW}$1${NC}"
}

section() {
    echo -e "\n${BLUE}$1${NC}"
}

# Check if Claude CLI is available
check_claude() {
    if ! command -v claude &> /dev/null; then
        echo "WARNING: Claude Code CLI not found - behavioral tests will be skipped"
        echo "Install Claude Code to run behavioral tests"
        return 1
    fi
    return 0
}

echo "========================================"
echo " GGCoder Reviewer Behavioral Tests"
echo "========================================"
echo ""
echo "Plugin root: $PLUGIN_ROOT"
echo ""

# Check for Claude CLI
CLAUDE_AVAILABLE=false
if check_claude; then
    CLAUDE_AVAILABLE=true
    echo "Claude CLI: $(claude --version 2>/dev/null || echo 'available')"
fi
echo ""

# ============================================
# Test Fixtures: Code Samples with Known Issues
# ============================================

# Create test fixtures directory
FIXTURES_DIR=$(mktemp -d)
trap "rm -rf $FIXTURES_DIR" EXIT

# Fixture 1: Concurrency issue (missing synchronization)
cat > "$FIXTURES_DIR/ConcurrencyIssue.java" <<'EOF'
package com.example;

import java.util.HashMap;
import java.util.Map;

public class CacheManager {
    private Map<String, Object> cache = new HashMap<>();
    private volatile boolean initialized = false;

    public void put(String key, Object value) {
        // BUG: HashMap is not thread-safe
        cache.put(key, value);
    }

    public Object get(String key) {
        return cache.get(key);
    }

    public void initialize() {
        if (!initialized) {
            // BUG: Check-then-act race condition
            loadFromDisk();
            initialized = true;
        }
    }

    private void loadFromDisk() {
        // Load cache entries
    }
}
EOF

# Fixture 2: Resource leak
cat > "$FIXTURES_DIR/ResourceLeak.java" <<'EOF'
package com.example;

import java.io.*;

public class FileProcessor {
    public String readFile(String path) throws IOException {
        // BUG: FileInputStream never closed
        FileInputStream fis = new FileInputStream(path);
        BufferedReader reader = new BufferedReader(new InputStreamReader(fis));

        StringBuilder content = new StringBuilder();
        String line;
        while ((line = reader.readLine()) != null) {
            content.append(line);
        }

        return content.toString();
        // Missing: fis.close() or try-with-resources
    }
}
EOF

# Fixture 3: Null safety issue
cat > "$FIXTURES_DIR/NullIssue.java" <<'EOF'
package com.example;

public class UserService {
    public String getUserDisplayName(User user) {
        // BUG: No null check on user
        String firstName = user.getFirstName();
        String lastName = user.getLastName();

        // BUG: firstName or lastName could be null
        return firstName + " " + lastName;
    }

    public void processUser(User user) {
        String name = getUserDisplayName(user);
        // BUG: name could contain "null null" if both are null
        System.out.println("Processing: " + name);
    }
}

class User {
    private String firstName;
    private String lastName;

    public String getFirstName() { return firstName; }
    public String getLastName() { return lastName; }
}
EOF

# Fixture 4: Good code (no issues)
cat > "$FIXTURES_DIR/GoodCode.java" <<'EOF'
package com.example;

import java.util.concurrent.ConcurrentHashMap;
import java.util.Map;
import java.util.Objects;

public class SafeCacheManager {
    private final Map<String, Object> cache = new ConcurrentHashMap<>();

    public void put(String key, Object value) {
        Objects.requireNonNull(key, "key cannot be null");
        Objects.requireNonNull(value, "value cannot be null");
        cache.put(key, value);
    }

    public Object get(String key) {
        Objects.requireNonNull(key, "key cannot be null");
        return cache.get(key);
    }
}
EOF

echo "Test fixtures created in: $FIXTURES_DIR"
echo ""

# ============================================
# Static Tests: Reviewer Agent Configuration
# ============================================
section "1. Reviewer Agent Configuration Tests"

# Test that safety reviewer mentions concurrency patterns
info "Testing gg-safety-reviewer configuration..."
safety_agent="$PLUGIN_ROOT/agents/gg-safety-reviewer.md"

if [ -f "$safety_agent" ]; then
    # Check for concurrency pattern skill reference
    if grep -qi "concurrency" "$safety_agent"; then
        pass "gg-safety-reviewer references concurrency"
    else
        fail "gg-safety-reviewer missing concurrency" "Should reference concurrency patterns"
    fi

    # Check for resource cleanup reference
    if grep -qi "resource" "$safety_agent"; then
        pass "gg-safety-reviewer references resources"
    else
        fail "gg-safety-reviewer missing resource handling" "Should reference resource patterns"
    fi

    # Check for confidence threshold mention
    if grep -qi "confidence\|80%\|Critical\|High" "$safety_agent"; then
        pass "gg-safety-reviewer has confidence guidance"
    else
        fail "gg-safety-reviewer missing confidence" "Should mention confidence thresholds"
    fi
else
    fail "gg-safety-reviewer.md not found" "Expected: agents/gg-safety-reviewer.md"
fi

# Test quality reviewer
info "Testing gg-quality-reviewer configuration..."
quality_agent="$PLUGIN_ROOT/agents/gg-quality-reviewer.md"

if [ -f "$quality_agent" ]; then
    # Quality reviewer should handle lower-severity issues
    if grep -qi "dead code\|duplication\|style" "$quality_agent"; then
        pass "gg-quality-reviewer handles quality issues"
    else
        fail "gg-quality-reviewer missing quality patterns" "Should cover dead code, duplication, style"
    fi
else
    fail "gg-quality-reviewer.md not found" "Expected: agents/gg-quality-reviewer.md"
fi

# Test testing reviewer
info "Testing gg-testing-reviewer configuration..."
testing_agent="$PLUGIN_ROOT/agents/gg-testing-reviewer.md"

if [ -f "$testing_agent" ]; then
    if grep -qi "coverage\|assertion\|flaky\|test" "$testing_agent"; then
        pass "gg-testing-reviewer handles test issues"
    else
        fail "gg-testing-reviewer missing test patterns" "Should cover coverage, assertions, flakiness"
    fi
else
    fail "gg-testing-reviewer.md not found" "Expected: agents/gg-testing-reviewer.md"
fi

echo ""

# ============================================
# Behavioral Tests: Reviewer Detection (requires Claude CLI)
# ============================================
section "2. Behavioral Tests: Issue Detection"

if [ "$CLAUDE_AVAILABLE" = false ]; then
    skip "All behavioral tests (Claude CLI not available)"
else
    info "These tests invoke Claude to verify reviewer behavior"
    info "Each test may take 30-60 seconds..."
    echo ""

    # Test 2.1: Safety reviewer should detect concurrency issue
    info "Test 2.1: Concurrency issue detection"

    concurrency_prompt="You are the gg-safety-reviewer agent. Review this code for safety issues:

\`\`\`java
$(cat "$FIXTURES_DIR/ConcurrencyIssue.java")
\`\`\`

Focus on: thread safety, race conditions, synchronization.
Report issues with confidence levels (Critical 80%+, High 85%+)."

    # Run with timeout
    if output=$(run_with_timeout 120 claude -p "$concurrency_prompt" --allowedTools "" 2>&1); then
        # Check if it found the thread safety issue
        if echo "$output" | grep -qi "thread.safe\|HashMap\|synchronized\|ConcurrentHashMap\|race"; then
            pass "Detected thread safety issue in HashMap usage"
        else
            fail "Missed thread safety issue" "Should detect non-thread-safe HashMap"
        fi

        # Check if it found the check-then-act race
        if echo "$output" | grep -qi "check.then.act\|race.condition\|double.check\|initialized"; then
            pass "Detected check-then-act race condition"
        else
            fail "Missed check-then-act race" "Should detect race in initialize()"
        fi
    else
        fail "Claude invocation failed or timed out" "Exit code: $?"
    fi

    echo ""

    # Test 2.2: Safety reviewer should detect resource leak
    info "Test 2.2: Resource leak detection"

    resource_prompt="You are the gg-safety-reviewer agent. Review this code for resource management issues:

\`\`\`java
$(cat "$FIXTURES_DIR/ResourceLeak.java")
\`\`\`

Focus on: resource cleanup, try-with-resources, stream closing."

    if output=$(run_with_timeout 120 claude -p "$resource_prompt" --allowedTools "" 2>&1); then
        if echo "$output" | grep -qi "close\|resource.leak\|try.with.resources\|finally\|AutoCloseable"; then
            pass "Detected resource leak (unclosed stream)"
        else
            fail "Missed resource leak" "Should detect unclosed FileInputStream"
        fi
    else
        fail "Claude invocation failed or timed out" "Exit code: $?"
    fi

    echo ""

    # Test 2.3: Should find null safety issues
    info "Test 2.3: Null safety detection"

    null_prompt="You are the gg-safety-reviewer agent. Review this code for null safety:

\`\`\`java
$(cat "$FIXTURES_DIR/NullIssue.java")
\`\`\`

Focus on: null checks, NullPointerException prevention, defensive programming."

    if output=$(run_with_timeout 120 claude -p "$null_prompt" --allowedTools "" 2>&1); then
        if echo "$output" | grep -qi "null\|NullPointerException\|Objects.requireNonNull\|@Nullable"; then
            pass "Detected null safety issues"
        else
            fail "Missed null safety issues" "Should detect missing null checks"
        fi
    else
        fail "Claude invocation failed or timed out" "Exit code: $?"
    fi

    echo ""

    # Test 2.4: Should not raise false positives on good code
    info "Test 2.4: No false positives on clean code"

    good_prompt="You are the gg-safety-reviewer agent. Review this code:

\`\`\`java
$(cat "$FIXTURES_DIR/GoodCode.java")
\`\`\`

Report only genuine issues with confidence 80%+. If the code is safe, say so."

    if output=$(run_with_timeout 120 claude -p "$good_prompt" --allowedTools "" 2>&1); then
        # Should NOT find major issues
        if echo "$output" | grep -qi "no.issues\|looks.good\|safe\|well.written\|no.concerns\|clean"; then
            pass "No false positives on clean code"
        elif echo "$output" | grep -qi "Critical\|High.*issue\|must.fix"; then
            fail "False positive on clean code" "Should not report Critical/High issues"
        else
            pass "Reviewed without major issues (neutral response)"
        fi
    else
        fail "Claude invocation failed or timed out" "Exit code: $?"
    fi
fi

echo ""

# ============================================
# Test 3: Layered Review Order
# ============================================
section "3. Layered Review Process Tests"

info "Testing review command configuration..."

review_cmd="$PLUGIN_ROOT/commands/review.md"

if [ -f "$review_cmd" ]; then
    # Check for layered review mention
    if grep -qi "layer\|pass.1\|pass.2\|domain.*first\|architecture.*after" "$review_cmd"; then
        pass "Review command describes layered process"
    else
        fail "Review command missing layered process" "Should describe Pass 1 (domain) then Pass 2 (architecture)"
    fi

    # Check that it references domain reviewers
    if grep -qi "gg-safety\|gg-quality\|gg-testing" "$review_cmd"; then
        pass "Review command references domain reviewers"
    else
        fail "Review command missing domain reviewers" "Should reference gg-* reviewers"
    fi

    # Check that it references architecture review
    if grep -qi "code-reviewer\|architecture" "$review_cmd"; then
        pass "Review command references architecture review"
    else
        fail "Review command missing architecture review" "Should reference code-reviewer agent"
    fi
else
    fail "review.md command not found" "Expected: commands/review.md"
fi

echo ""

# ============================================
# Summary
# ============================================
echo "========================================"
echo " Test Results Summary"
echo "========================================"
echo ""
echo -e "  ${GREEN}Passed:${NC}  $passed"
echo -e "  ${RED}Failed:${NC}  $failed"
echo -e "  ${YELLOW}Skipped:${NC} $skipped"
echo ""

if [ $failed -gt 0 ]; then
    echo -e "${RED}STATUS: FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}STATUS: PASSED${NC}"
    exit 0
fi
