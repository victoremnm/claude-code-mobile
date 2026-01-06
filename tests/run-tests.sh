#!/usr/bin/env bash
#
# Run all tests for claude-code-mobile
#
# Usage: ./run-tests.sh [unit|integration|all]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

TEST_TYPE="${1:-all}"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  Claude Code Mobile - Test Suite"
echo "════════════════════════════════════════════════════════════════"
echo ""

FAILED=0

run_unit_tests() {
    echo -e "${YELLOW}▶ Running unit tests...${NC}"
    echo ""
    if bash "$SCRIPT_DIR/test-ntfy-notify.sh"; then
        echo ""
    else
        FAILED=1
    fi
}

run_integration_tests() {
    echo -e "${YELLOW}▶ Running integration tests...${NC}"
    echo ""
    if bash "$SCRIPT_DIR/test-setup-hooks.sh"; then
        echo ""
    else
        FAILED=1
    fi
}

case "$TEST_TYPE" in
    unit)
        run_unit_tests
        ;;
    integration)
        run_integration_tests
        ;;
    all|*)
        run_unit_tests
        run_integration_tests
        ;;
esac

echo ""
if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  All tests passed!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
    exit 0
else
    echo -e "${RED}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}  Some tests failed${NC}"
    echo -e "${RED}════════════════════════════════════════════════════════════════${NC}"
    exit 1
fi
