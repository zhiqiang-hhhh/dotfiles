#!/usr/bin/env bash
# install/iterm2.sh - Point iTerm2 Dynamic Profiles to dotfiles managed config

if [[ -z "${BASH_VERSION:-}" ]]; then
    exec bash "$0" "$@"
fi

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
source "$SCRIPT_DIR/_common.sh"

ITERM2_DYNAMIC_PROFILES_DIR="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
ITERM2_PROFILE_LINK="$ITERM2_DYNAMIC_PROFILES_DIR/dotfiles.json"
ITERM2_PROFILE_TARGET="$DOTFILES_DIR/iterm2/DynamicProfiles/dotfiles.json"

install_iterm2() {
    echo
    info "=== iTerm2 Dynamic Profile Symlink Setup ==="
    echo

    if [[ "$(uname -s)" != "Darwin" ]]; then
        warn "iTerm2 is macOS-only; skipping on this platform"
        return 0
    fi

    if [[ ! -f "$ITERM2_PROFILE_TARGET" ]]; then
        warn "iTerm2 profile target not found: $ITERM2_PROFILE_TARGET"
        warn "Make sure dotfiles repo contains iterm2/DynamicProfiles/dotfiles.json"
        return 1
    fi

    mkdir -p "$ITERM2_DYNAMIC_PROFILES_DIR"

    if [[ -L "$ITERM2_PROFILE_LINK" ]]; then
        local current_target
        current_target="$(readlink "$ITERM2_PROFILE_LINK")"
        if [[ "$current_target" == "$ITERM2_PROFILE_TARGET" || "$ITERM2_PROFILE_LINK" -ef "$ITERM2_PROFILE_TARGET" ]]; then
            success "iTerm2 dynamic profile symlink already points to dotfiles"
            return 0
        fi
        info "Updating existing symlink target"
    elif [[ -e "$ITERM2_PROFILE_LINK" ]]; then
        local backup
        backup="${ITERM2_PROFILE_LINK}.bak.$(date +%Y%m%d%H%M%S)"
        cp "$ITERM2_PROFILE_LINK" "$backup"
        warn "Backed up existing iTerm2 dynamic profile to $backup"
    fi

    ln -sfn "$ITERM2_PROFILE_TARGET" "$ITERM2_PROFILE_LINK"
    success "Linked $ITERM2_PROFILE_LINK -> $ITERM2_PROFILE_TARGET"
    info "Restart iTerm2, then select the 'dotfiles' profile or set it as default."
}

if [[ "${BASH_SOURCE[0]:-$0}" == "$0" ]]; then
    install_iterm2
fi
