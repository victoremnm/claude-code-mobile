#!/usr/bin/env bash
#
# Integration tests for setup-hooks script
#
# Usage: ./test-setup-hooks.sh
#
# These tests run in an isolated environment to verify the setup process

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETUP_SCRIPT="$SCRIPT_DIR/scripts/setup-hooks"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Create isolated test environment
TEST_HOME=$(mktemp -d)
trap "rm -rf $TEST_HOME" EXIT

# Test helper
assert() {
    local name="$1"
    local condition="$2"

    TESTS_RUN=$((TESTS_RUN + 1))

    if eval "$condition"; then
        echo -e "${GREEN}✓${NC} $name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Mock curl for testing
setup_mock_env() {
    local test_home="$1"

    # Create mock curl
    mkdir -p "$test_home/bin"
    cat > "$test_home/bin/curl" << 'EOF'
#!/usr/bin/env bash
echo '{"id":"test","event":"message"}'
EOF
    chmod +x "$test_home/bin/curl"

    # Export test environment
    export HOME="$test_home"
    export PATH="$test_home/bin:$PATH"
}

echo ""
echo "Running setup-hooks integration tests..."
echo ""

# =============================================================================
# Test 1: Script shows usage without arguments
# =============================================================================

TESTS_RUN=$((TESTS_RUN + 1))
if output=$("$SETUP_SCRIPT" 2>&1); then
    echo -e "${RED}✗${NC} shows usage without arguments (should exit non-zero)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
else
    if [[ "$output" == *"Usage:"* ]]; then
        echo -e "${GREEN}✓${NC} shows usage without arguments"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} shows usage without arguments"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
fi

# =============================================================================
# Test 2: Creates required directories
# =============================================================================

test_home_2=$(mktemp -d)
trap "rm -rf $test_home_2" EXIT
setup_mock_env "$test_home_2"

"$SETUP_SCRIPT" "test-topic-123" > /dev/null 2>&1 || true

assert "creates ~/.claude/hooks directory" \
    "[[ -d '$test_home_2/.claude/hooks' ]]"

assert "creates ~/.config/claude-mobile directory" \
    "[[ -d '$test_home_2/.config/claude-mobile' ]]"

# =============================================================================
# Test 3: Installs hook script
# =============================================================================

assert "installs ntfy-notify.sh hook" \
    "[[ -f '$test_home_2/.claude/hooks/ntfy-notify.sh' ]]"

assert "hook script is executable" \
    "[[ -x '$test_home_2/.claude/hooks/ntfy-notify.sh' ]]"

# =============================================================================
# Test 4: Creates config with correct topic
# =============================================================================

assert "creates config file" \
    "[[ -f '$test_home_2/.config/claude-mobile/config' ]]"

assert "config contains correct topic" \
    "grep -q 'NTFY_TOPIC=\"test-topic-123\"' '$test_home_2/.config/claude-mobile/config'"

# =============================================================================
# Test 5: Creates Claude settings.json
# =============================================================================

assert "creates settings.json" \
    "[[ -f '$test_home_2/.claude/settings.json' ]]"

assert "settings.json contains AskUserQuestion hook" \
    "grep -q 'AskUserQuestion' '$test_home_2/.claude/settings.json'"

assert "settings.json references ntfy-notify.sh" \
    "grep -q 'ntfy-notify.sh' '$test_home_2/.claude/settings.json'"

# =============================================================================
# Test 6: Preserves existing settings.json
# =============================================================================

test_home_3=$(mktemp -d)
trap "rm -rf $test_home_3" EXIT
setup_mock_env "$test_home_3"

# Create existing settings
mkdir -p "$test_home_3/.claude"
echo '{"existing": "config"}' > "$test_home_3/.claude/settings.json"

output=$("$SETUP_SCRIPT" "test-topic" 2>&1) || true

TESTS_RUN=$((TESTS_RUN + 1))
if [[ "$output" == *"Existing"*"settings.json"* ]]; then
    echo -e "${GREEN}✓${NC} warns about existing settings.json"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} warns about existing settings.json"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

assert "preserves existing settings.json content" \
    "grep -q 'existing' '$test_home_3/.claude/settings.json'"

# =============================================================================
# Test 7: Hook script works after setup
# =============================================================================

test_home_4=$(mktemp -d)
trap "rm -rf $test_home_4" EXIT
setup_mock_env "$test_home_4"

"$SETUP_SCRIPT" "integration-test-topic" > /dev/null 2>&1 || true

# Run the installed hook
cd "$test_home_4"
TESTS_RUN=$((TESTS_RUN + 1))
if output=$("$test_home_4/.claude/hooks/ntfy-notify.sh" test 2>&1); then
    if [[ "$output" == *"integration-test-topic"* ]]; then
        echo -e "${GREEN}✓${NC} installed hook sends test notification"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} installed hook sends test notification"
        echo "  Expected output to contain: integration-test-topic"
        echo "  Got: $output"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
else
    echo -e "${RED}✗${NC} installed hook sends test notification (command failed)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# =============================================================================
# Results
# =============================================================================

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "Results: $TESTS_PASSED/$TESTS_RUN passed"
if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "${RED}$TESTS_FAILED tests failed${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
