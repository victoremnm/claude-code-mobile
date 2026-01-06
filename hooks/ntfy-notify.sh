#!/usr/bin/env bash
#
# ntfy-notify.sh - Send push notifications via ntfy.sh when Claude needs input
#
# Usage: ntfy-notify.sh <event_type>
#
# Environment variables:
#   NTFY_TOPIC  - Your ntfy topic name (required)
#   NTFY_SERVER - ntfy server URL (default: https://ntfy.sh)
#   EVENT_DATA  - JSON data from Claude Code hook (set automatically)
#
# Install:
#   1. Install ntfy app on your phone (iOS/Android)
#   2. Subscribe to a topic (e.g., "claude-code-yourname")
#   3. Add the topic to ~/.config/claude-mobile/config
#   4. Add this hook to ~/.claude/settings.json

set -euo pipefail

# Configuration
CONFIG_FILE="${HOME}/.config/claude-mobile/config"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

NTFY_TOPIC="${NTFY_TOPIC:-}"
NTFY_SERVER="${NTFY_SERVER:-https://ntfy.sh}"
EVENT_TYPE="${1:-unknown}"

# Get project name from current directory
PROJECT_NAME="${PWD##*/}"

notify() {
    local message="$1"
    local title="${2:-Claude Code}"
    local priority="${3:-default}"

    if [[ -z "$NTFY_TOPIC" ]]; then
        echo "Warning: NTFY_TOPIC not set" >&2
        return 1
    fi

    curl -s -X POST "${NTFY_SERVER}/${NTFY_TOPIC}" \
        -H "Title: $title" \
        -H "Priority: $priority" \
        -H "Tags: robot" \
        -d "$message" > /dev/null
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
        notify "[$PROJECT_NAME] $question" "Claude needs input: $header" "high"
    else
        notify "[$PROJECT_NAME] Claude is waiting for your input" "Claude Code" "high"
    fi
}

handle_tool_blocked() {
    local tool_name=""

    if [[ -n "${EVENT_DATA:-}" ]]; then
        tool_name=$(echo "$EVENT_DATA" | jq -r '.tool_name // empty' 2>/dev/null || echo "")
    fi

    if [[ -n "$tool_name" ]]; then
        notify "[$PROJECT_NAME] Tool blocked: $tool_name" "Claude Code - Approval Needed" "high"
    else
        notify "[$PROJECT_NAME] A tool requires your approval" "Claude Code - Approval Needed" "high"
    fi
}

handle_error() {
    local error_msg=""

    if [[ -n "${EVENT_DATA:-}" ]]; then
        error_msg=$(echo "$EVENT_DATA" | jq -r '.error // empty' 2>/dev/null || echo "")
    fi

    notify "[$PROJECT_NAME] Error: ${error_msg:-Unknown error}" "Claude Code - Error" "urgent"
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
    test)
        notify "Test notification from Claude Code Mobile" "Test" "default"
        echo "Test notification sent to topic: $NTFY_TOPIC"
        ;;
    *)
        notify "[$PROJECT_NAME] Claude needs attention" "Claude Code"
        ;;
esac
