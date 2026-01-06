# Add these lines to your ~/.zshrc on the VM
# Auto-attach to tmux session on SSH login

# Only run in interactive shells and not already in tmux
if [[ -z "$TMUX" && $- == *i* ]]; then
    # Check if we're connecting via SSH
    if [[ -n "$SSH_CONNECTION" ]]; then
        # Try to attach to existing session, or create new one
        tmux attach -t main 2>/dev/null || tmux new -s main
    fi
fi

# Useful aliases for Claude Code mobile development
alias cc="claude"
alias ccc="claude --continue"
alias ccr="claude --resume"

# Quick project navigation
alias proj="cd ~/Code"

# Git worktree helpers
alias gwl="git worktree list"
alias gwa="git worktree add"
alias gwr="git worktree remove"

# Create a new worktree for a feature branch
gwf() {
    local branch="$1"
    local project_name="${PWD##*/}"
    if [[ -z "$branch" ]]; then
        echo "Usage: gwf <branch-name>"
        return 1
    fi
    git worktree add "../${project_name}-${branch}" -b "$branch"
    cd "../${project_name}-${branch}"
}

# VM status check (useful alias)
alias vmstatus="vm-status"

# Show Claude agents running in tmux windows
agents() {
    echo "Claude agents in tmux windows:"
    tmux list-windows -F '#I: #W - #{pane_current_path}' 2>/dev/null || echo "Not in tmux"
}

# Quick new tmux window for parallel development
newagent() {
    local name="${1:-agent}"
    tmux new-window -n "$name"
}
