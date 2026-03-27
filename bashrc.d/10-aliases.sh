# bashrc.d/10-aliases.sh - Common aliases

# --- Git ---
alias gs='git status'
alias gd='git diff'
alias gds='git diff --staged'
alias gl='git log --oneline -20'
alias gla='git log --oneline --all --graph -30'
alias ga='git add'
alias gc='git commit'
alias gco='git checkout'
alias gb='git branch'
alias gp='git push'
alias gpl='git pull'
alias gf='git fetch --all --prune'
alias gst='git stash'
alias gstp='git stash pop'

# --- File listing ---
alias ll='ls -alh --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias lt='ls -alht --color=auto'  # Sort by time

# --- Safety ---
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# --- Navigation ---
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# --- Grep ---
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# --- Disk ---
alias df='df -h'
alias du='du -h'
alias dud='du -h -d 1'  # One-level deep summary

# --- Process ---
alias psg='ps aux | grep -v grep | grep'

# --- Network ---
alias ports='ss -tlnp'

# --- Misc ---
alias h='history'
alias j='jobs -l'
alias path='echo -e ${PATH//:/\\n}'  # Print PATH entries one per line
alias now='date +"%Y-%m-%d %H:%M:%S"'
