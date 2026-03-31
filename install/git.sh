#!/usr/bin/env bash
# install/git.sh - Install git and deploy gitconfig

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/code/dotfiles}"

info()    { printf "\033[34m[INFO]\033[0m %s\n" "$1"; }
warn()    { printf "\033[33m[WARN]\033[0m %s\n" "$1"; }
success() { printf "\033[32m[ OK ]\033[0m %s\n" "$1"; }

install_git() {
    echo
    info "=== Git Setup ==="
    echo

    if command -v git &>/dev/null; then
        success "Git is already installed: $(git --version)"
    else
        info "Installing git..."
        if command -v brew &>/dev/null; then
            brew install git
        elif command -v yum &>/dev/null; then
            sudo yum install -y git
        elif command -v apt-get &>/dev/null; then
            sudo apt-get update && sudo apt-get install -y git
        else
            warn "Could not detect package manager. Please install git manually."
            return 1
        fi
        success "Git installed: $(git --version)"
    fi
}

configure_git() {
    local gitconfig_src="$DOTFILES_DIR/gitconfig"
    local gitconfig_dst="$HOME/.gitconfig"

    if [[ ! -f "$gitconfig_src" ]]; then
        warn "gitconfig template not found at $gitconfig_src"
        return 1
    fi

    # Get user info interactively
    local current_name current_email
    current_name="$(git config --global user.name 2>/dev/null || echo '')"
    current_email="$(git config --global user.email 2>/dev/null || echo '')"

    read -rp "Git user name [${current_name:-your name}]: " git_name
    git_name="${git_name:-$current_name}"

    read -rp "Git user email [${current_email:-your email}]: " git_email
    git_email="${git_email:-$current_email}"

    if [[ -z "$git_name" || -z "$git_email" ]]; then
        warn "Name and email are required for git config"
        return 1
    fi

    # Backup existing gitconfig
    if [[ -f "$gitconfig_dst" ]]; then
        cp "$gitconfig_dst" "${gitconfig_dst}.bak.$(date +%Y%m%d%H%M%S)"
        info "Backed up existing .gitconfig"
    fi

    # Render template: replace placeholders
    sed -e "s|__GIT_NAME__|${git_name}|g" \
        -e "s|__GIT_EMAIL__|${git_email}|g" \
        "$gitconfig_src" > "$gitconfig_dst"

    success "Git configured: name=$git_name, email=$git_email"
    success "Written to $gitconfig_dst"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_git
    configure_git
fi
