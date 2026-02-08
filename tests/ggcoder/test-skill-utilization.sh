#!/bin/bash
# Test that ggcoder skills are actually FOLLOWED, not just loaded
# Based on writing-skills TDD methodology: test that agent behavior changes with skill
#
# Key insight: Loading a skill is necessary but not sufficient.
# We must verify the agent's behavior matches what the skill prescribes.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Cross-platform timeout function (works on macOS without coreutils)
run_with_timeout() {
    local timeout_seconds="$1"
    shift

    # Try GNU timeout first (Linux or macOS with coreutils)
    if command -v timeout &> /dev/null; then
        timeout "$timeout_seconds" "$@"
        return $?
    elif command -v gtimeout &> /dev/null; then
        gtimeout "$timeout_seconds" "$@"
        return $?
    else
        # Fallback: run without timeout on macOS
        # The claude CLI has its own --max-turns limit
        "$@"
        return $?
    fi
}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================"
echo " GGCoder Skill Utilization Tests"
echo "========================================"
echo ""
echo "These tests verify skills are FOLLOWED, not just loaded."
echo "Each test checks for specific behavioral indicators."
echo ""

# Check for Claude CLI
if ! command -v claude &> /dev/null; then
    echo -e "${YELLOW}SKIP: Claude CLI not found${NC}"
    echo "Install Claude Code to run skill utilization tests"
    exit 0
fi

TIMESTAMP=$(date +%s)
OUTPUT_BASE="/tmp/ggcoder-tests/${TIMESTAMP}/utilization"
mkdir -p "$OUTPUT_BASE"

passed=0
failed=0

# Extract assistant responses from stream-json log
extract_responses() {
    local log_file="$1"
    grep '"type":"assistant"' "$log_file" 2>/dev/null | \
        jq -r '.message.content[]? | select(.type=="text") | .text' 2>/dev/null || true
}

# Check if specific tool was used
check_tool_used() {
    local log_file="$1"
    local tool_name="$2"
    grep -q "\"name\":\"$tool_name\"" "$log_file" 2>/dev/null
}

# Test: TDD skill should cause test-before-code behavior
test_tdd_behavior() {
    echo -e "\n${BLUE}Test: TDD skill causes test-first behavior${NC}"

    local output_dir="$OUTPUT_BASE/tdd-behavior"
    mkdir -p "$output_dir"
    local log_file="$output_dir/output.json"
    local project_dir="$output_dir/project"
    mkdir -p "$project_dir/src" "$project_dir/tests"

    cd "$project_dir"
    git init -q 2>/dev/null || true

    # Pressure scenario: Ask for implementation (natural temptation is to write code first)
    local prompt="Implement a function called 'isPrime' that checks if a number is prime. Put it in src/math.js"

    run_with_timeout 300 claude -p "$prompt" \
        --plugin-dir "$PLUGIN_DIR" \
        --dangerously-skip-permissions \
        --max-turns 8 \
        --output-format stream-json --verbose \
        > "$log_file" 2>&1 || true

    # Check for TDD indicators
    local responses=$(extract_responses "$log_file")

    # TDD skill should cause:
    # 1. Mention of writing test first
    # 2. Test file created before or alongside implementation
    # 3. Language about "failing test" or "RED" phase

    local indicators=0
    local indicator_details=""

    if echo "$responses" | grep -qi "test.*first\|write.*test\|RED.*phase\|failing.*test"; then
        indicators=$((indicators + 1))
        indicator_details="$indicator_details\n    - Mentioned test-first approach"
    fi

    if echo "$responses" | grep -qi "test.*fail\|watch.*fail\|expect.*fail"; then
        indicators=$((indicators + 1))
        indicator_details="$indicator_details\n    - Mentioned watching test fail"
    fi

    # Check if test file was created
    if [ -f "$project_dir/tests/math.test.js" ] || [ -f "$project_dir/src/math.test.js" ] || \
       ls "$project_dir"/**/*.test.js 2>/dev/null | grep -q .; then
        indicators=$((indicators + 1))
        indicator_details="$indicator_details\n    - Test file created"
    fi

    # Check Write tool order (test before implementation)
    local first_write=$(grep '"name":"Write"' "$log_file" | head -1)
    if echo "$first_write" | grep -qi "test"; then
        indicators=$((indicators + 1))
        indicator_details="$indicator_details\n    - First Write was for test file"
    fi

    echo "  Indicators found: $indicators/4"
    echo -e "$indicator_details"

    if [ $indicators -ge 2 ]; then
        echo -e "  ${GREEN}[PASS]${NC} TDD behavior detected"
        passed=$((passed + 1))
    else
        echo -e "  ${RED}[FAIL]${NC} TDD behavior not detected"
        echo "    Expected test-first approach, got implementation-first"
        echo "    Log: $log_file"
        failed=$((failed + 1))
    fi
}

# Test: Debugging skill should follow systematic process
test_debugging_behavior() {
    echo -e "\n${BLUE}Test: Debugging skill causes systematic process${NC}"

    local output_dir="$OUTPUT_BASE/debugging-behavior"
    mkdir -p "$output_dir"
    local log_file="$output_dir/output.json"
    local project_dir="$output_dir/project"
    mkdir -p "$project_dir/src"

    # Create buggy code
    cat > "$project_dir/src/app.js" <<'EOF'
function processUser(user) {
    // Bug: doesn't handle null user
    const name = user.name.toUpperCase();
    return `Hello, ${name}!`;
}

module.exports = { processUser };
EOF

    cd "$project_dir"
    git init -q 2>/dev/null || true

    local prompt="There's a bug in src/app.js - it crashes with 'Cannot read property name of null'. Fix it."

    run_with_timeout 300 claude -p "$prompt" \
        --plugin-dir "$PLUGIN_DIR" \
        --dangerously-skip-permissions \
        --max-turns 8 \
        --output-format stream-json --verbose \
        > "$log_file" 2>&1 || true

    local responses=$(extract_responses "$log_file")

    # Debugging skill should cause:
    # 1. Hypothesis formation
    # 2. Evidence gathering (reading code)
    # 3. Root cause identification
    # 4. Verification after fix

    local indicators=0
    local indicator_details=""

    if echo "$responses" | grep -qi "hypothes\|suspect\|likely\|probably"; then
        indicators=$((indicators + 1))
        indicator_details="$indicator_details\n    - Formed hypothesis"
    fi

    if check_tool_used "$log_file" "Read"; then
        indicators=$((indicators + 1))
        indicator_details="$indicator_details\n    - Read file to gather evidence"
    fi

    if echo "$responses" | grep -qi "root.*cause\|because\|the.*issue.*is\|the.*problem.*is"; then
        indicators=$((indicators + 1))
        indicator_details="$indicator_details\n    - Identified root cause"
    fi

    if echo "$responses" | grep -qi "null.*check\|guard\|defensive\|validate"; then
        indicators=$((indicators + 1))
        indicator_details="$indicator_details\n    - Proposed appropriate fix"
    fi

    echo "  Indicators found: $indicators/4"
    echo -e "$indicator_details"

    if [ $indicators -ge 2 ]; then
        echo -e "  ${GREEN}[PASS]${NC} Systematic debugging behavior detected"
        passed=$((passed + 1))
    else
        echo -e "  ${RED}[FAIL]${NC} Systematic debugging not detected"
        echo "    Expected hypothesis + evidence gathering"
        echo "    Log: $log_file"
        failed=$((failed + 1))
    fi
}

# Test: Concurrency patterns skill provides GridGain-specific guidance
test_concurrency_patterns() {
    echo -e "\n${BLUE}Test: Concurrency patterns provides GridGain-specific guidance${NC}"

    local output_dir="$OUTPUT_BASE/concurrency-patterns"
    mkdir -p "$output_dir"
    local log_file="$output_dir/output.json"
    local project_dir="$output_dir/project"
    mkdir -p "$project_dir/src"

    cd "$project_dir"
    git init -q 2>/dev/null || true

    local prompt="I'm working on GridGain/Ignite code. How should I handle concurrent access to a shared cache? What patterns should I use?"

    run_with_timeout 180 claude -p "$prompt" \
        --plugin-dir "$PLUGIN_DIR" \
        --dangerously-skip-permissions \
        --max-turns 5 \
        --output-format stream-json --verbose \
        > "$log_file" 2>&1 || true

    local responses=$(extract_responses "$log_file")

    # Concurrency patterns skill should mention:
    local indicators=0
    local indicator_details=""

    if echo "$responses" | grep -qi "ConcurrentHashMap\|ConcurrentMap"; then
        indicators=$((indicators + 1))
        indicator_details="$indicator_details\n    - Mentioned ConcurrentHashMap"
    fi

    if echo "$responses" | grep -qi "synchronized\|lock\|ReentrantLock"; then
        indicators=$((indicators + 1))
        indicator_details="$indicator_details\n    - Mentioned synchronization"
    fi

    if echo "$responses" | grep -qi "atomic\|AtomicReference\|AtomicInteger"; then
        indicators=$((indicators + 1))
        indicator_details="$indicator_details\n    - Mentioned atomic operations"
    fi

    if echo "$responses" | grep -qi "thread.safe\|race\|concurrent"; then
        indicators=$((indicators + 1))
        indicator_details="$indicator_details\n    - Discussed thread safety"
    fi

    echo "  Indicators found: $indicators/4"
    echo -e "$indicator_details"

    if [ $indicators -ge 2 ]; then
        echo -e "  ${GREEN}[PASS]${NC} Concurrency guidance provided"
        passed=$((passed + 1))
    else
        echo -e "  ${RED}[FAIL]${NC} Concurrency patterns not utilized"
        echo "    Expected thread-safety patterns"
        echo "    Log: $log_file"
        failed=$((failed + 1))
    fi
}

# Test: Review command dispatches layered review
test_layered_review() {
    echo -e "\n${BLUE}Test: Review uses layered process (domain then architecture)${NC}"

    local output_dir="$OUTPUT_BASE/layered-review"
    mkdir -p "$output_dir"
    local log_file="$output_dir/output.json"
    local project_dir="$output_dir/project"
    mkdir -p "$project_dir/src"

    # Create code with issues for review
    cat > "$project_dir/src/Service.java" <<'EOF'
package com.example;

import java.util.HashMap;
import java.io.FileInputStream;

public class Service {
    private HashMap<String, Object> data = new HashMap<>();

    public void loadFile(String path) throws Exception {
        FileInputStream fis = new FileInputStream(path);
        // Resource leak: never closed
        byte[] content = fis.readAllBytes();
    }
}
EOF

    cd "$project_dir"
    git init -q 2>/dev/null || true
    git add . 2>/dev/null || true
    git commit -m "initial" -q 2>/dev/null || true

    local prompt="Run /review on this code"

    run_with_timeout 600 claude -p "$prompt" \
        --plugin-dir "$PLUGIN_DIR" \
        --dangerously-skip-permissions \
        --max-turns 10 \
        --output-format stream-json --verbose \
        > "$log_file" 2>&1 || true

    local responses=$(extract_responses "$log_file")

    # Layered review should:
    # 1. Mention Pass 1 / domain reviewers
    # 2. Dispatch gg-* agents
    # 3. Find the concurrency and resource issues
    # 4. Mention Pass 2 / architecture review

    local indicators=0
    local indicator_details=""

    if echo "$responses" | grep -qi "pass.1\|domain.*review\|safety.*review"; then
        indicators=$((indicators + 1))
        indicator_details="$indicator_details\n    - Mentioned domain review phase"
    fi

    if grep -q "gg-safety-reviewer\|gg-quality-reviewer" "$log_file"; then
        indicators=$((indicators + 1))
        indicator_details="$indicator_details\n    - Dispatched gg-* reviewer"
    fi

    if echo "$responses" | grep -qi "thread.safe\|HashMap\|ConcurrentHashMap"; then
        indicators=$((indicators + 1))
        indicator_details="$indicator_details\n    - Found thread safety issue"
    fi

    if echo "$responses" | grep -qi "resource.*leak\|close\|try.with.resource\|FileInputStream"; then
        indicators=$((indicators + 1))
        indicator_details="$indicator_details\n    - Found resource leak"
    fi

    echo "  Indicators found: $indicators/4"
    echo -e "$indicator_details"

    if [ $indicators -ge 2 ]; then
        echo -e "  ${GREEN}[PASS]${NC} Layered review behavior detected"
        passed=$((passed + 1))
    else
        echo -e "  ${RED}[FAIL]${NC} Layered review not working"
        echo "    Expected domain reviewers + issue detection"
        echo "    Log: $log_file"
        failed=$((failed + 1))
    fi
}

echo ""
echo "========================================="
echo " Running Utilization Tests"
echo "========================================="

test_tdd_behavior
test_debugging_behavior
test_concurrency_patterns
test_layered_review

echo ""
echo "========================================="
echo " Summary"
echo "========================================="
echo ""
echo -e "  ${GREEN}Passed:${NC}  $passed"
echo -e "  ${RED}Failed:${NC}  $failed"
echo ""
echo "Full logs: $OUTPUT_BASE"
echo ""

if [ $failed -gt 0 ]; then
    echo -e "${RED}STATUS: FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}STATUS: PASSED${NC}"
    exit 0
fi
