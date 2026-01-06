#!/usr/bin/env bash
#
# Unit tests for ntfy-notify.sh
#
# Usage: ./test-ntfy-notify.sh
#
# These tests mock the curl command to avoid sending real notifications

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK_SCRIPT="$SCRIPT_DIR/hooks/ntfy-notify.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Create temp directory for test fixtures
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

# Mock curl to capture calls
CURL_LOG="$TEST_DIR/curl_calls.log"
mock_curl() {
    cat > "$TEST_DIR/curl" << 'EOF'
#!/usr/bin/env bash
echo "CURL_CALL: $*" >> "$CURL_LOG_FILE"
echo '{"id":"test123","event":"message"}'
EOF
    chmod +x "$TEST_DIR/curl"
    export PATH="$TEST_DIR:$PATH"
    export CURL_LOG_FILE="$CURL_LOG"
}

# Test helper
run_test() {
    local name="$1"
    local expected="$2"
    shift 2

    TESTS_RUN=$((TESTS_RUN + 1))

    # Clear curl log
    > "$CURL_LOG"

    # Run the command
    if output=$("$@" 2>&1); then
        if [[ -f "$CURL_LOG" ]] && grep -q "$expected" "$CURL_LOG"; then
            echo -e "${GREEN}✓${NC} $name"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            return 0
        fi
    fi

    echo -e "${RED}✗${NC} $name"
    echo "  Expected: $expected"
    echo "  Got: $(cat "$CURL_LOG" 2>/dev/null || echo 'no curl calls')"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
}

run_test_no_curl() {
    local name="$1"
    local expected_output="$2"
    shift 2

    TESTS_RUN=$((TESTS_RUN + 1))

    if output=$("$@" 2>&1); then
        if [[ "$output" == *"$expected_output"* ]]; then
            echo -e "${GREEN}✓${NC} $name"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            return 0
        fi
    fi

    echo -e "${RED}✗${NC} $name"
    echo "  Expected output to contain: $expected_output"
    echo "  Got: $output"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 1
}

# Setup mock environment
setup() {
    mock_curl

    # Create mock config
    mkdir -p "$TEST_DIR/config"
    echo 'NTFY_TOPIC="test-topic"' > "$TEST_DIR/config/config"
    export HOME="$TEST_DIR"
    mkdir -p "$TEST_DIR/.config/claude-mobile"
    cp "$TEST_DIR/config/config" "$TEST_DIR/.config/claude-mobile/config"
}

echo ""
echo "Running ntfy-notify.sh unit tests..."
echo ""

# =============================================================================
# Unit Tests
# =============================================================================

setup

# Test 1: Question event sends high priority
run_test "question event sends notification" "Priority: high" \
    bash "$HOOK_SCRIPT" question

# Test 2: Test event works
setup
run_test "test event sends notification" "test-topic" \
    bash "$HOOK_SCRIPT" test

# Test 3: Error event sends urgent priority
setup
run_test "error event sends urgent priority" "Priority: urgent" \
    bash "$HOOK_SCRIPT" error

# Test 4: Stop event sends done notification
setup
run_test "stop event sends done notification" "Claude Code - Done" \
    bash "$HOOK_SCRIPT" stop

# Test 5: Blocked event sends approval notification
setup
run_test "blocked event sends approval notification" "Approval Needed" \
    bash "$HOOK_SCRIPT" blocked

# Test 6: Notification event works
setup
run_test "notification event works" "test-topic" \
    bash "$HOOK_SCRIPT" notification

# Test 7: Unknown event sends generic notification
setup
run_test "unknown event sends generic notification" "needs attention" \
    bash "$HOOK_SCRIPT" unknown_event

# Test 8: Missing topic shows warning
TESTS_RUN=$((TESTS_RUN + 1))
unset NTFY_TOPIC
export HOME="$TEST_DIR"
rm -f "$TEST_DIR/.config/claude-mobile/config"
mkdir -p "$TEST_DIR/.config/claude-mobile"
touch "$TEST_DIR/.config/claude-mobile/config"

if output=$(bash "$HOOK_SCRIPT" test 2>&1); then
    echo -e "${RED}✗${NC} missing topic shows warning (should have failed)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
else
    if [[ "$output" == *"NTFY_TOPIC not set"* ]]; then
        echo -e "${GREEN}✓${NC} missing topic shows warning"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} missing topic shows warning"
        echo "  Expected: NTFY_TOPIC not set"
        echo "  Got: $output"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
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
