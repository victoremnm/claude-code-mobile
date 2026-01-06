#!/usr/bin/env bash
#
# poke-notify.sh - Send push notifications via Poke when Claude needs input
#
# Usage: poke-notify.sh <event_type>
#
# Environment variables:
#   POKE_WEBHOOK_URL - Your Poke webhook URL
#   EVENT_DATA       - JSON data from Claude Code hook (set automatically)
#
# Install:
#   1. Get a Poke account at https://poke.dev
#   2. Create a webhook and copy the URL
#   3. Add the URL to ~/.config/claude-mobile/config
#   4. Add this hook to ~/.claude/settings.json

set -euo pipefail

# Configuration
CONFIG_FILE="${HOME}/.config/claude-mobile/config"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

POKE_WEBHOOK_URL="${POKE_WEBHOOK_URL:-}"
EVENT_TYPE="${1:-unknown}"

# Get project name from current directory
PROJECT_NAME="${PWD##*/}"

notify() {
    local message="$1"
    local title="${2:-Claude Code}"

    if [[ -z "$POKE_WEBHOOK_URL" ]]; then
        echo "Warning: POKE_WEBHOOK_URL not set" >&2
        return 1
    fi

    curl -s -X POST "$POKE_WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "{\"title\": \"$title\", \"message\": \"$message\"}" > /dev/null
}

handle_question() {
    local question=""
    local header=""

    if [[ -n "${EVENT_DATA:-}" ]]; then
        # Extract question from the hook data
        question=$(echo "$EVENT_DATA" | jq -r '.tool_input.questions[0].question // empty' 2>/dev/null || echo "")
        header=$(echo "$EVENT_DATA" | jq -r '.tool_input.questions[0].header // empty' 2>/dev/null || echo "")
    fi

    if [[ -n "$question" ]]; then
        notify "[$PROJECT_NAME] $question" "Claude needs input: $header"
    else
        notify "[$PROJECT_NAME] Claude is waiting for your input" "Claude Code"
    fi
}

handle_tool_blocked() {
    local tool_name=""

    if [[ -n "${EVENT_DATA:-}" ]]; then
        tool_name=$(echo "$EVENT_DATA" | jq -r '.tool_name // empty' 2>/dev/null || echo "")
    fi

    if [[ -n "$tool_name" ]]; then
        notify "[$PROJECT_NAME] Tool blocked: $tool_name" "Claude Code - Approval Needed"
    else
        notify "[$PROJECT_NAME] A tool requires your approval" "Claude Code - Approval Needed"
    fi
}

handle_error() {
    local error_msg=""

    if [[ -n "${EVENT_DATA:-}" ]]; then
        error_msg=$(echo "$EVENT_DATA" | jq -r '.error // empty' 2>/dev/null || echo "")
    fi

    notify "[$PROJECT_NAME] Error: ${error_msg:-Unknown error}" "Claude Code - Error"
}

case "$EVENT_TYPE" in
    question|ask)
        handle_question
        ;;
    blocked|approval)
        handle_tool_blocked
        ;;
    error)
        handle_error
        ;;
    *)
        notify "[$PROJECT_NAME] Claude needs attention" "Claude Code"
        ;;
esac
