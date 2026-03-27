# bashrc.d/20-prompt.sh - Custom PS1 with git branch

# Get current git branch name
__git_branch() {
    local branch
    branch="$(git symbolic-ref --short HEAD 2>/dev/null || git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)"
    if [[ -n "$branch" ]]; then
        # Check for uncommitted changes
        local dirty=""
        if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
            dirty="*"
        fi
        echo " [${branch}${dirty}]"
    fi
}

# Build PS1
# Format: user@host ~/path/to/dir [branch*]$
#   - Green user@host when local, red when SSH
#   - Blue path
#   - Yellow git branch, with * if dirty
if [[ -n "${SSH_CLIENT:-}${SSH_CONNECTION:-}" ]]; then
    # Remote session: show hostname in red
    PS1='\[\033[1;31m\]\u@\h\[\033[0m\] \[\033[34m\]\w\[\033[0m\]\[\033[33m\]$(__git_branch)\[\033[0m\]\$ '
else
    # Local session
    PS1='\[\033[1;32m\]\u@\h\[\033[0m\] \[\033[34m\]\w\[\033[0m\]\[\033[33m\]$(__git_branch)\[\033[0m\]\$ '
fi

export PS1
