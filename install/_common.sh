#!/usr/bin/env bash
#
# install/_common.sh - Shared helpers for install scripts
#
# Usage (in other install scripts):
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/_common.sh"
#

# ---- Helper functions (only define if not already defined) ----

if ! declare -f info &>/dev/null; then
    info()    { printf "\033[34m[INFO]\033[0m %s\n" "$1"; }
fi
if ! declare -f warn &>/dev/null; then
    warn()    { printf "\033[33m[WARN]\033[0m %s\n" "$1"; }
fi
if ! declare -f success &>/dev/null; then
    success() { printf "\033[32m[ OK ]\033[0m %s\n" "$1"; }
fi

# ---- Dotfiles directory ----

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/code/dotfiles}"

# ============================================================
# ensure_zsh_path - Make sure ~/.zshrc adds dotfiles bin to PATH
#
# zsh gets a minimal PATH-only block. Do not source bashrc.d/*
# from zsh because those files are Bash-oriented.
# ============================================================

ensure_zsh_path() {
    local zshrc="$HOME/.zshrc"
    local marker="# >>> dotfiles path >>>"

    if [[ -f "$zshrc" ]] && grep -qF "$marker" "$zshrc"; then
        return 0
    fi

    info "Adding dotfiles PATH block to $zshrc ..."

    if [[ -f "$zshrc" ]]; then
        local backup="${zshrc}.bak.$(date +%Y%m%d%H%M%S)"
        cp "$zshrc" "$backup"
        info "Backed up existing .zshrc to $backup"
    fi

    cat >> "$zshrc" << 'ZSHRC_BLOCK'

# >>> dotfiles path >>>
# Managed by https://github.com/zhiqiang-hhhh/dotfiles
# Do not edit this block manually.
export DOTFILES_DIR="$HOME/code/dotfiles"
[[ -d "$HOME/bin" ]] && export PATH="$HOME/bin:$PATH"
[[ -d "$DOTFILES_DIR/bin" ]] && export PATH="$DOTFILES_DIR/bin:$PATH"
typeset -U path PATH
# <<< dotfiles path <<<
ZSHRC_BLOCK

    success "Dotfiles PATH block added to $zshrc"
}

# ============================================================
# ensure_bashrc - Make sure ~/.bashrc sources bashrc.d/*
#
# Checks if the dotfiles source block exists in ~/.bashrc.
# If not, appends it (non-destructive, backs up first).
# This guarantees that PATH, JAVA_HOME, MAVEN_HOME, etc.
# from bashrc.d/ are available after tools are installed.
# ============================================================

ensure_bashrc() {
    local bashrc="$HOME/.bashrc"
    local marker="# >>> dotfiles >>>"

    # Already configured — nothing to do
    if [[ -f "$bashrc" ]] && grep -qF "$marker" "$bashrc"; then
        ensure_zsh_path
        return 0
    fi

    info "Adding dotfiles source block to $bashrc ..."

    # Backup existing .bashrc
    if [[ -f "$bashrc" ]]; then
        local backup="${bashrc}.bak.$(date +%Y%m%d%H%M%S)"
        cp "$bashrc" "$backup"
        info "Backed up existing .bashrc to $backup"
    fi

    # Append the source block (identical to bootstrap.sh Step 6)
    cat >> "$bashrc" << 'BASHRC_BLOCK'

# >>> dotfiles >>>
# Managed by https://github.com/zhiqiang-hhhh/dotfiles
# Do not edit this block manually.
export DOTFILES_DIR="$HOME/code/dotfiles"
if [[ -d "$DOTFILES_DIR/bashrc.d" ]]; then
    for _dotfile in "$DOTFILES_DIR/bashrc.d"/*.sh; do
        [[ -f "$_dotfile" ]] && source "$_dotfile"
    done
    unset _dotfile
fi
# <<< dotfiles <<<
BASHRC_BLOCK

    success "Dotfiles source block added to $bashrc"
    ensure_zsh_path
}

# ============================================================
# hint_source_bashrc - Remind the user to reload their shell
# ============================================================

hint_source_bashrc() {
    echo
    if [[ -n "${ZSH_VERSION:-}" || "${SHELL:-}" == */zsh ]]; then
        info "Detected zsh. Dotfiles bin PATH is managed in ~/.zshrc."
        info "To activate PATH changes in your current shell, run:"
        echo
        echo "  source ~/.zshrc"
        echo
        info "Bash-only helper functions are still managed in ~/.bashrc."
        echo
        return 0
    fi

    info "To activate the new environment in your current shell, run:"
    echo
    echo "  source ~/.bashrc"
    echo
}
