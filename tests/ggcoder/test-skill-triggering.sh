#!/bin/bash
# Test that ggcoder skills are triggered correctly
# Verifies skills get invoked from natural prompts AND that skill content is followed

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

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

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================"
echo " GGCoder Skill Triggering Tests"
echo "========================================"
echo ""

# Check for Claude CLI
if ! command -v claude &> /dev/null; then
    echo -e "${YELLOW}SKIP: Claude CLI not found${NC}"
    echo "Install Claude Code to run skill triggering tests"
    exit 0
fi

TIMESTAMP=$(date +%s)
OUTPUT_BASE="/tmp/ggcoder-tests/${TIMESTAMP}"
mkdir -p "$OUTPUT_BASE"

passed=0
failed=0
skipped=0

# Test function that runs a prompt and checks for skill invocation
test_skill_trigger() {
    local test_name="$1"
    local skill_name="$2"
    local prompt="$3"
    local expected_pattern="$4"  # Pattern to verify skill was USED (not just loaded)
    local max_turns="${5:-3}"

    echo -e "\n${BLUE}Test: $test_name${NC}"
    echo "  Skill: $skill_name"
    echo "  Checking: $expected_pattern"

    local output_dir="$OUTPUT_BASE/$test_name"
    mkdir -p "$output_dir"

    local log_file="$output_dir/claude-output.json"

    # Create minimal project structure
    local project_dir="$output_dir/project"
    mkdir -p "$project_dir"
    cd "$project_dir"

    # Run Claude
    run_with_timeout 180 claude -p "$prompt" \
        --plugin-dir "$PLUGIN_DIR" \
        --dangerously-skip-permissions \
        --max-turns "$max_turns" \
        --output-format stream-json --verbose \
        > "$log_file" 2>&1 || true

    # Check if skill was triggered
    # skill_name can be a pipe-separated list of alternatives (e.g., "tdd|test-driven-development")
    local triggered=false

    if grep -q '"name":"Skill"' "$log_file"; then
        # Check each skill name alternative
        for alt_skill in $(echo "$skill_name" | tr '|' ' '); do
            local skill_pattern='"skill":"([^"]*:)?'"${alt_skill}"'"'
            if grep -qE "$skill_pattern" "$log_file"; then
                triggered=true
                break
            fi
        done
    fi

    # Check if expected pattern appears (skill was actually used)
    local utilized=false
    if [ -n "$expected_pattern" ]; then
        if grep -qi "$expected_pattern" "$log_file"; then
            utilized=true
        fi
    else
        utilized=true  # No pattern to check
    fi

    # Report result
    if [ "$triggered" = true ] && [ "$utilized" = true ]; then
        echo -e "  ${GREEN}[PASS]${NC} Skill triggered and utilized"
        passed=$((passed + 1))
        return 0
    elif [ "$triggered" = true ]; then
        echo -e "  ${YELLOW}[PARTIAL]${NC} Skill triggered but pattern not found"
        echo "    Expected: $expected_pattern"
        echo "    Log: $log_file"
        failed=$((failed + 1))
        return 1
    else
        echo -e "  ${RED}[FAIL]${NC} Skill not triggered"
        echo "    Skills that WERE triggered:"
        grep -o '"skill":"[^"]*"' "$log_file" 2>/dev/null | sort -u | sed 's/^/      /' || echo "      (none)"
        echo "    Log: $log_file"
        failed=$((failed + 1))
        return 1
    fi
}

# Test function for agent dispatching
test_agent_dispatch() {
    local test_name="$1"
    local agent_name="$2"
    local prompt="$3"
    local max_turns="${4:-5}"

    echo -e "\n${BLUE}Test: $test_name${NC}"
    echo "  Agent: $agent_name"

    local output_dir="$OUTPUT_BASE/$test_name"
    mkdir -p "$output_dir"

    local log_file="$output_dir/claude-output.json"

    # Create project with code to review
    local project_dir="$output_dir/project"
    mkdir -p "$project_dir/src"

    # Create a file with known issues for the reviewer to find
    cat > "$project_dir/src/Example.java" <<'EOF'
package com.example;

import java.util.HashMap;
import java.util.Map;

public class Example {
    private Map<String, Object> cache = new HashMap<>();

    public void addToCache(String key, Object value) {
        // Thread-safety issue: HashMap not synchronized
        cache.put(key, value);
    }

    public Object getFromCache(String key) {
        return cache.get(key);
    }
}
EOF

    cd "$project_dir"
    git init -q 2>/dev/null || true

    # Run Claude
    run_with_timeout 300 claude -p "$prompt" \
        --plugin-dir "$PLUGIN_DIR" \
        --dangerously-skip-permissions \
        --max-turns "$max_turns" \
        --output-format stream-json --verbose \
        > "$log_file" 2>&1 || true

    # Check if agent was dispatched via Task tool
    local dispatched=false

    # Look for Task tool invocation with the agent name
    if grep -q '"name":"Task"' "$log_file" && grep -qi "$agent_name" "$log_file"; then
        dispatched=true
    fi

    if [ "$dispatched" = true ]; then
        echo -e "  ${GREEN}[PASS]${NC} Agent dispatched"
        passed=$((passed + 1))
        return 0
    else
        echo -e "  ${RED}[FAIL]${NC} Agent not dispatched"
        echo "    Log: $log_file"
        failed=$((failed + 1))
        return 1
    fi
}

echo ""
echo "========================================="
echo " 1. Skill Triggering Tests"
echo "========================================="

# Test: using-ggcoder should be available at session start
# (This is injected by hook, not triggered by prompt)
echo -e "\n${YELLOW}Note: using-ggcoder is injected by SessionStart hook, not triggered${NC}"

# Test: brainstorming skill triggers on feature request
test_skill_trigger \
    "brainstorming-feature-request" \
    "brainstorming" \
    "I want to add a user authentication feature to my app. Let's think through the requirements." \
    "brainstorming\|requirements\|design" \
    3

# Test: test-driven-development triggers on implementation request
# Note: Claude may trigger 'tdd' command or 'test-driven-development' skill
test_skill_trigger \
    "tdd-implementation" \
    "tdd\|test-driven-development" \
    "Help me implement a function to validate email addresses using TDD." \
    "test.*first\|RED.*GREEN\|failing test" \
    3

# Test: systematic-debugging triggers on bug report
test_skill_trigger \
    "debugging-bug-report" \
    "systematic-debugging" \
    "I have a bug where users are getting logged out randomly. The session seems to expire too early." \
    "hypothes\|reproduce\|isolate\|root cause" \
    3

# Test: concurrency-patterns triggers on thread safety question
test_skill_trigger \
    "concurrency-patterns" \
    "concurrency-patterns" \
    "I need help making my HashMap thread-safe in Java. What patterns should I use for GridGain?" \
    "ConcurrentHashMap\|synchronized\|thread.safe" \
    3

# Test: review-pr triggers on PR review request
test_skill_trigger \
    "review-pr-request" \
    "review-pr" \
    "Please review the changes in this PR for any issues." \
    "review\|safety\|quality" \
    3

echo ""
echo "========================================="
echo " 2. Skill Utilization Tests"
echo "========================================="

# Test: TDD skill should enforce write-test-first
test_skill_trigger \
    "tdd-enforces-test-first" \
    "test-driven-development" \
    "Implement a calculateTotal function that sums prices with tax." \
    "write.*test\|test.*first\|failing" \
    5

# Test: Debugging skill should follow systematic process
test_skill_trigger \
    "debugging-follows-process" \
    "systematic-debugging" \
    "My API returns 500 errors intermittently. Debug this." \
    "Phase\|hypothesis\|reproduce\|evidence" \
    5

echo ""
echo "========================================="
echo " 3. Agent Dispatch Tests"
echo "========================================="

# Test: /review should dispatch gg-safety-reviewer
test_agent_dispatch \
    "review-dispatches-safety" \
    "gg-safety-reviewer" \
    "Run /review on the code in src/" \
    5

# Test: Explicit reviewer request
test_agent_dispatch \
    "explicit-safety-review" \
    "gg-safety-reviewer" \
    "Use the gg-safety-reviewer agent to review src/Example.java for concurrency issues." \
    5

echo ""
echo "========================================="
echo " Summary"
echo "========================================="
echo ""
echo -e "  ${GREEN}Passed:${NC}  $passed"
echo -e "  ${RED}Failed:${NC}  $failed"
echo -e "  ${YELLOW}Skipped:${NC} $skipped"
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
