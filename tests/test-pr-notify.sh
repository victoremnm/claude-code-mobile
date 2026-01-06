#!/usr/bin/env bash
#
# Unit tests for pr-notify script
#
# Usage: ./test-pr-notify.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PR_NOTIFY="$SCRIPT_DIR/scripts/pr-notify"

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

setup_mock_env() {
    # Create mock curl
    mkdir -p "$TEST_DIR/bin"
    cat > "$TEST_DIR/bin/curl" << 'EOF'
#!/usr/bin/env bash
echo "CURL_CALL: $*" >> "$CURL_LOG_FILE"
echo '{"id":"test"}'
EOF
    chmod +x "$TEST_DIR/bin/curl"

    # Create mock gh
    cat > "$TEST_DIR/bin/gh" << 'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"pr view"*"--json url"* ]]; then
    echo "https://github.com/test/repo/pull/42"
elif [[ "$*" == *"pr view"*"--json title"* ]]; then
    echo "Test PR Title"
fi
EOF
    chmod +x "$TEST_DIR/bin/gh"

    # Create config
    mkdir -p "$TEST_DIR/.config/claude-mobile"
    echo 'NTFY_TOPIC="test-topic"' > "$TEST_DIR/.config/claude-mobile/config"

    export HOME="$TEST_DIR"
    export PATH="$TEST_DIR/bin:$PATH"
    export CURL_LOG_FILE="$TEST_DIR/curl.log"
}

echo ""
echo "Running pr-notify unit tests..."
echo ""

# =============================================================================
# Test 1: Fails without NTFY_TOPIC
# =============================================================================

TESTS_RUN=$((TESTS_RUN + 1))
unset NTFY_TOPIC
export HOME="$TEST_DIR"
rm -rf "$TEST_DIR/.config"
mkdir -p "$TEST_DIR/.config/claude-mobile"
touch "$TEST_DIR/.config/claude-mobile/config"

if output=$(bash "$PR_NOTIFY" "https://github.com/test/repo/pull/1" 2>&1); then
    echo -e "${RED}✗${NC} fails without NTFY_TOPIC (should have failed)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
else
    if [[ "$output" == *"NTFY_TOPIC not set"* ]]; then
        echo -e "${GREEN}✓${NC} fails without NTFY_TOPIC"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} fails without NTFY_TOPIC"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
fi

# =============================================================================
# Test 2: Sends notification with PR URL
# =============================================================================

setup_mock_env
> "$CURL_LOG_FILE"

TESTS_RUN=$((TESTS_RUN + 1))
if output=$(bash "$PR_NOTIFY" "https://github.com/test/repo/pull/123" 2>&1); then
    if grep -q "test-topic" "$CURL_LOG_FILE" && grep -q "Click:" "$CURL_LOG_FILE"; then
        echo -e "${GREEN}✓${NC} sends notification with PR URL"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} sends notification with PR URL"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
else
    echo -e "${RED}✗${NC} sends notification with PR URL (command failed)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# =============================================================================
# Test 3: Extracts PR number from URL
# =============================================================================

setup_mock_env
> "$CURL_LOG_FILE"

TESTS_RUN=$((TESTS_RUN + 1))
if output=$(bash "$PR_NOTIFY" "https://github.com/owner/repo/pull/456" 2>&1); then
    if [[ "$output" == *"#456"* ]]; then
        echo -e "${GREEN}✓${NC} extracts PR number from URL"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} extracts PR number from URL"
        echo "  Output: $output"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
else
    echo -e "${RED}✗${NC} extracts PR number from URL (command failed)"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# =============================================================================
# Test 4: Sets high priority
# =============================================================================

setup_mock_env
> "$CURL_LOG_FILE"

TESTS_RUN=$((TESTS_RUN + 1))
bash "$PR_NOTIFY" "https://github.com/test/repo/pull/1" > /dev/null 2>&1 || true

if grep -q "Priority: high" "$CURL_LOG_FILE"; then
    echo -e "${GREEN}✓${NC} sets high priority"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} sets high priority"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# =============================================================================
# Test 5: Includes click URL
# =============================================================================

setup_mock_env
> "$CURL_LOG_FILE"

TESTS_RUN=$((TESTS_RUN + 1))
bash "$PR_NOTIFY" "https://github.com/test/repo/pull/789" > /dev/null 2>&1 || true

if grep -q "Click: https://github.com/test/repo/pull/789" "$CURL_LOG_FILE"; then
    echo -e "${GREEN}✓${NC} includes clickable URL"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${RED}✗${NC} includes clickable URL"
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
