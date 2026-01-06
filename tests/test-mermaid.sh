#!/usr/bin/env bash
#
# test-mermaid.sh - Validate Mermaid diagram syntax in README.md
#
# Usage: ./test-mermaid.sh
#
# This script extracts Mermaid diagrams and validates their syntax

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
README="$SCRIPT_DIR/README.md"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Temp directory
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

echo ""
echo "Running Mermaid diagram validation..."
echo ""

# Extract mermaid blocks from README
extract_mermaid_blocks() {
    awk '/^```mermaid$/,/^```$/' "$README" | grep -v '^```'
}

# Count mermaid blocks
BLOCK_COUNT=$(grep -c '^```mermaid$' "$README" || echo "0")

if [[ "$BLOCK_COUNT" -eq 0 ]]; then
    echo -e "${RED}✗${NC} No Mermaid diagrams found in README.md"
    exit 1
fi

echo "Found $BLOCK_COUNT Mermaid diagram(s)"
echo ""

# Extract mermaid blocks to temp files
awk '/^```mermaid$/,/^```$/{
    if(/^```mermaid$/){
        blocknum++
        next
    }
    if(/^```$/){
        next
    }
    print > ("'"$TEST_DIR"'/diagram_" blocknum ".mmd")
}' "$README"

# Validate each extracted block
for diagram_file in "$TEST_DIR"/diagram_*.mmd; do
    [[ -f "$diagram_file" ]] || continue

    BLOCK_NUM=$(basename "$diagram_file" | sed 's/diagram_\([0-9]*\)\.mmd/\1/')
    TESTS_RUN=$((TESTS_RUN + 1))

    block=$(cat "$diagram_file")

    # Basic syntax checks
    ERRORS=""

    # Check for flowchart/graph declaration
    if ! echo "$block" | head -1 | grep -qE '^(flowchart|graph|sequenceDiagram|classDiagram|stateDiagram|erDiagram|journey|gantt|pie|gitGraph)'; then
        ERRORS="Missing or invalid diagram type declaration"
    fi

    # Check for unbalanced brackets
    OPEN_BRACKETS=$(echo "$block" | tr -cd '[' | wc -c)
    CLOSE_BRACKETS=$(echo "$block" | tr -cd ']' | wc -c)
    if [[ "$OPEN_BRACKETS" -ne "$CLOSE_BRACKETS" ]]; then
        ERRORS="${ERRORS:+$ERRORS; }Unbalanced brackets: $OPEN_BRACKETS [ vs $CLOSE_BRACKETS ]"
    fi

    # Check for unbalanced parentheses
    OPEN_PARENS=$(echo "$block" | tr -cd '(' | wc -c)
    CLOSE_PARENS=$(echo "$block" | tr -cd ')' | wc -c)
    if [[ "$OPEN_PARENS" -ne "$CLOSE_PARENS" ]]; then
        ERRORS="${ERRORS:+$ERRORS; }Unbalanced parentheses: $OPEN_PARENS ( vs $CLOSE_PARENS )"
    fi

    # Check for unbalanced quotes
    QUOTE_COUNT=$(echo "$block" | tr -cd '"' | wc -c)
    if [[ $((QUOTE_COUNT % 2)) -ne 0 ]]; then
        ERRORS="${ERRORS:+$ERRORS; }Unbalanced quotes"
    fi

    # Check for problematic HTML-like tags that GitHub may not render
    if echo "$block" | grep -qE '<br\s*/?>|<br>'; then
        ERRORS="${ERRORS:+$ERRORS; }Contains <br/> tags which may not render on GitHub"
    fi

    # Check for subgraph end statements
    SUBGRAPH_COUNT=$(echo "$block" | grep -c 'subgraph' 2>/dev/null || true)
    END_COUNT=$(echo "$block" | grep -cE '^\s*end\s*$' 2>/dev/null || true)
    SUBGRAPH_COUNT=${SUBGRAPH_COUNT:-0}
    END_COUNT=${END_COUNT:-0}
    if [[ "$SUBGRAPH_COUNT" -ne "$END_COUNT" ]]; then
        ERRORS="${ERRORS:+$ERRORS; }Mismatched subgraph/end: $SUBGRAPH_COUNT subgraphs vs $END_COUNT ends"
    fi

    # Report result
    if [[ -z "$ERRORS" ]]; then
        echo -e "${GREEN}✓${NC} Diagram $BLOCK_NUM: Valid syntax"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗${NC} Diagram $BLOCK_NUM: $ERRORS"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
done

# =============================================================================
# Results
# =============================================================================

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "Results: $TESTS_PASSED/$TESTS_RUN diagrams valid"
if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "${RED}$TESTS_FAILED diagram(s) have issues${NC}"
    exit 1
else
    echo -e "${GREEN}All diagrams valid!${NC}"
    exit 0
fi
