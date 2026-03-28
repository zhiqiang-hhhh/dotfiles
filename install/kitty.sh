#!/usr/bin/env bash
# install/kitty.sh - Point kitty config to dotfiles managed config

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
source "$SCRIPT_DIR/_common.sh"

KITTY_CONFIG_DIR="$HOME/.config/kitty"
KITTY_CONFIG_LINK="$KITTY_CONFIG_DIR/kitty.conf"
KITTY_CONFIG_TARGET="$DOTFILES_DIR/kitty/kitty.conf"

install_kitty() {
    echo
    info "=== Kitty Config Symlink Setup ==="
    echo

    if [[ ! -f "$KITTY_CONFIG_TARGET" ]]; then
        warn "Kitty config target not found: $KITTY_CONFIG_TARGET"
        warn "Make sure dotfiles repo contains kitty/kitty.conf"
        return 1
    fi

    mkdir -p "$KITTY_CONFIG_DIR"

    if [[ -L "$KITTY_CONFIG_LINK" ]]; then
        local current_target
        current_target="$(readlink "$KITTY_CONFIG_LINK")"
        if [[ "$current_target" == "$KITTY_CONFIG_TARGET" || "$KITTY_CONFIG_LINK" -ef "$KITTY_CONFIG_TARGET" ]]; then
            success "kitty.conf symlink already points to dotfiles"
            return 0
        fi
        info "Updating existing symlink target"
    elif [[ -e "$KITTY_CONFIG_LINK" ]]; then
        local backup
        backup="${KITTY_CONFIG_LINK}.bak.$(date +%Y%m%d%H%M%S)"
        cp "$KITTY_CONFIG_LINK" "$backup"
        warn "Backed up existing kitty.conf to $backup"
    fi

    ln -sfn "$KITTY_CONFIG_TARGET" "$KITTY_CONFIG_LINK"
    success "Linked $KITTY_CONFIG_LINK -> $KITTY_CONFIG_TARGET"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    install_kitty
fi
