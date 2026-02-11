#!/usr/bin/env bash
# Structural tests for ggcoder plugin
# Verifies naming consistency, paths, hook output, and component configuration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

passed=0
failed=0

pass() {
    echo -e "  ${GREEN}[PASS]${NC} $1"
    passed=$((passed + 1))
}

fail() {
    echo -e "  ${RED}[FAIL]${NC} $1"
    echo "        $2"
    failed=$((failed + 1))
}

info() {
    echo -e "${YELLOW}$1${NC}"
}

echo "========================================"
echo " GGCoder Structural Tests"
echo "========================================"
echo ""
echo "Plugin root: $PLUGIN_ROOT"
echo ""

# ============================================
# Test 1: Naming Consistency
# ============================================
info "1. Naming Consistency Tests"

# 1.1 using-ggcoder skill exists
if [ -f "$PLUGIN_ROOT/skills/using-ggcoder/SKILL.md" ]; then
    pass "using-ggcoder skill exists"
else
    fail "using-ggcoder skill missing" "Expected: skills/using-ggcoder/SKILL.md"
fi

# 1.2 using-superpowers should NOT exist (renamed)
if [ -f "$PLUGIN_ROOT/skills/using-superpowers/SKILL.md" ]; then
    fail "using-superpowers still exists" "Should be renamed to using-ggcoder"
else
    pass "using-superpowers correctly removed"
fi

# 1.3 Skill name in frontmatter is correct
if grep -q "^name: using-ggcoder$" "$PLUGIN_ROOT/skills/using-ggcoder/SKILL.md" 2>/dev/null; then
    pass "using-ggcoder frontmatter name correct"
else
    fail "using-ggcoder frontmatter name incorrect" "Expected: name: using-ggcoder"
fi

# 1.4 Session hook references using-ggcoder
if grep -q "using-ggcoder" "$PLUGIN_ROOT/hooks/session-start.sh" 2>/dev/null; then
    pass "session-start.sh references using-ggcoder"
else
    fail "session-start.sh missing using-ggcoder reference" "Hook should inject using-ggcoder skill"
fi

# 1.5 Config paths use ggcoder (not superpowers) in relevant skills
superpowers_config_refs="0"
if grep -rq "~/.config/superpowers/" "$PLUGIN_ROOT/skills/" --include="*.md" 2>/dev/null; then
    superpowers_config_refs=$(grep -rh "~/.config/superpowers/" "$PLUGIN_ROOT/skills/" --include="*.md" 2>/dev/null | grep -v "legacy" | grep -v "migrate" | wc -l | tr -d '[:space:]')
fi
if [ "$superpowers_config_refs" -eq 0 ]; then
    pass "No non-legacy ~/.config/superpowers/ references in skills"
else
    fail "Found ~/.config/superpowers/ references" "Should use ~/.config/ggcoder/ instead"
fi

echo ""

# ============================================
# Test 2: Hook Script Tests
# ============================================
info "2. Hook Script Tests"

# 2.1 session-start.sh is executable
if [ -x "$PLUGIN_ROOT/hooks/session-start.sh" ]; then
    pass "session-start.sh is executable"
else
    fail "session-start.sh is not executable" "chmod +x needed"
fi

# 2.2 Hook outputs valid JSON
hook_output=$("$PLUGIN_ROOT/hooks/session-start.sh" 2>&1)
if echo "$hook_output" | jq . >/dev/null 2>&1; then
    pass "session-start.sh outputs valid JSON"
else
    fail "session-start.sh outputs invalid JSON" "Output: ${hook_output:0:100}..."
fi

# 2.3 Hook JSON has required structure
if echo "$hook_output" | jq -e '.hookSpecificOutput.hookEventName' >/dev/null 2>&1; then
    pass "Hook output has hookEventName"
else
    fail "Hook output missing hookEventName" "Required: .hookSpecificOutput.hookEventName"
fi

if echo "$hook_output" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null 2>&1; then
    pass "Hook output has additionalContext"
else
    fail "Hook output missing additionalContext" "Required: .hookSpecificOutput.additionalContext"
fi

# 2.4 Hook context mentions ggcoder powers
context=$(echo "$hook_output" | jq -r '.hookSpecificOutput.additionalContext')
if echo "$context" | grep -q "ggcoder powers"; then
    pass "Hook context mentions 'ggcoder powers'"
else
    fail "Hook context missing 'ggcoder powers'" "Should say 'You have ggcoder powers'"
fi

# 2.5 Hook context references using-ggcoder skill
if echo "$context" | grep -q "using-ggcoder"; then
    pass "Hook context references using-ggcoder skill"
else
    fail "Hook context missing using-ggcoder reference" "Should reference ggcoder:using-ggcoder skill"
fi

echo ""

# ============================================
# Test 3: Agent Configuration Tests
# ============================================
info "3. Agent Configuration Tests"

# 3.1 All gg- agents exist
gg_agents=("gg-safety-reviewer" "gg-quality-reviewer" "gg-testing-reviewer" "gg-cpp-reviewer" "gg-build-reviewer"
           "gg-safety-fixer" "gg-quality-fixer" "gg-test-fixer" "gg-doc-fixer" "gg-cpp-fixer" "gg-build-fixer")

for agent in "${gg_agents[@]}"; do
    if [ -f "$PLUGIN_ROOT/agents/${agent}.md" ]; then
        pass "Agent ${agent}.md exists"
    else
        fail "Agent ${agent}.md missing" "Expected: agents/${agent}.md"
    fi
done

# 3.2 Agents have required frontmatter
for agent in "${gg_agents[@]}"; do
    agent_file="$PLUGIN_ROOT/agents/${agent}.md"
    if [ -f "$agent_file" ]; then
        if grep -q "^name:" "$agent_file" && grep -q "^description:" "$agent_file"; then
            pass "Agent $agent has name and description"
        else
            fail "Agent $agent missing frontmatter" "Required: name: and description:"
        fi
    fi
done

# 3.3 General code-reviewer agent exists
if [ -f "$PLUGIN_ROOT/agents/code-reviewer.md" ]; then
    pass "code-reviewer.md agent exists"
else
    fail "code-reviewer.md missing" "Required for architecture review"
fi

echo ""

# ============================================
# Test 4: Command Configuration Tests
# ============================================
info "4. Command Configuration Tests"

commands=("review" "fix" "brainstorm" "execute-plan" "write-plan" "code-review" "pr-review")

for cmd in "${commands[@]}"; do
    cmd_file="$PLUGIN_ROOT/commands/${cmd}.md"
    if [ -f "$cmd_file" ]; then
        pass "Command ${cmd}.md exists"
        # Check for description in frontmatter (required)
        if grep -q "^description:" "$cmd_file"; then
            pass "Command $cmd has description frontmatter"
        else
            fail "Command $cmd missing description frontmatter" "Required: description:"
        fi
    else
        fail "Command ${cmd}.md missing" "Expected: commands/${cmd}.md"
    fi
done

echo ""

# ============================================
# Test 5: Skill Files Exist
# ============================================
info "5. GridGain Pattern Skills Tests"

gg_skills=("concurrency-patterns" "resource-cleanup-patterns" "null-check-patterns"
           "async-patterns" "test-patterns" "performance-patterns"
           "version-compatibility-patterns" "security-context-patterns" "review-pr")

for skill in "${gg_skills[@]}"; do
    skill_file="$PLUGIN_ROOT/skills/${skill}/SKILL.md"
    if [ -f "$skill_file" ]; then
        pass "Skill ${skill}/SKILL.md exists"
    else
        fail "Skill ${skill}/SKILL.md missing" "Expected: skills/${skill}/SKILL.md"
    fi
done

echo ""

# ============================================
# Test 6: Plugin Manifest Tests
# ============================================
info "6. Plugin Manifest Tests"

# 6.1 plugin.json exists and is valid
plugin_json="$PLUGIN_ROOT/.claude-plugin/plugin.json"
if [ -f "$plugin_json" ]; then
    pass "plugin.json exists"

    if jq . "$plugin_json" >/dev/null 2>&1; then
        pass "plugin.json is valid JSON"

        # Check name is ggcoder
        if jq -e '.name == "ggcoder"' "$plugin_json" >/dev/null 2>&1; then
            pass "plugin.json name is 'ggcoder'"
        else
            fail "plugin.json name incorrect" "Expected: ggcoder"
        fi
    else
        fail "plugin.json is invalid JSON" "Parse error"
    fi
else
    fail "plugin.json missing" "Expected: .claude-plugin/plugin.json"
fi

# 6.2 marketplace.json exists and is valid
marketplace_json="$PLUGIN_ROOT/.claude-plugin/marketplace.json"
if [ -f "$marketplace_json" ]; then
    pass "marketplace.json exists"

    if jq . "$marketplace_json" >/dev/null 2>&1; then
        pass "marketplace.json is valid JSON"

        # Check plugin name
        if jq -e '.plugins[0].name == "ggcoder"' "$marketplace_json" >/dev/null 2>&1; then
            pass "marketplace.json plugin name is 'ggcoder'"
        else
            fail "marketplace.json plugin name incorrect" "Expected: ggcoder"
        fi
    else
        fail "marketplace.json is invalid JSON" "Parse error"
    fi
else
    fail "marketplace.json missing" "Expected: .claude-plugin/marketplace.json"
fi

echo ""

# ============================================
# Test 7: Conflict Detection Tests
# ============================================
info "7. Conflict Detection Tests"

# 7.1 Hook has superpowers conflict detection
if grep -q "superpowers.*conflict\|CONFLICT.*superpowers" "$PLUGIN_ROOT/hooks/session-start.sh" 2>/dev/null; then
    pass "Hook has superpowers conflict detection"
else
    fail "Hook missing conflict detection" "Should detect if superpowers plugin is also installed"
fi

# 7.2 Hook has legacy directory detection
if grep -q "legacy_skills_dir\|\.config/superpowers/skills" "$PLUGIN_ROOT/hooks/session-start.sh" 2>/dev/null; then
    pass "Hook has legacy directory detection"
else
    fail "Hook missing legacy detection" "Should detect ~/.config/superpowers/skills"
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
echo ""

if [ $failed -gt 0 ]; then
    echo -e "${RED}STATUS: FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}STATUS: PASSED${NC}"
    exit 0
fi
