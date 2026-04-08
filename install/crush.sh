#!/usr/bin/env bash
# install/crush.sh - Build crush from the bundled submodule and link it into bin/

if [[ -z "${BASH_VERSION:-}" ]]; then
    exec bash "$0" "$@"
fi

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
source "$SCRIPT_DIR/_common.sh"

CRUSH_DIR="$DOTFILES_DIR/crush"
CRUSH_BIN_DIR="$HOME/tools/crush/bin"
CRUSH_BINARY="$CRUSH_BIN_DIR/crush"
CRUSH_LINK="$DOTFILES_DIR/bin/crush"
CRUSH_REPO_URL="git@github.com:zhiqiang-hhhh/crush.git"

_ensure_crush_source() {
    if [[ -f "$CRUSH_DIR/go.mod" && -f "$CRUSH_DIR/main.go" ]]; then
        return 0
    fi

    if ! command -v git &>/dev/null; then
        warn "crush source is missing and git is not available to initialize the submodule."
        warn "Install git first, then run: git submodule update --init --recursive crush"
        return 1
    fi

    if [[ -d "$CRUSH_DIR/.git" || -f "$DOTFILES_DIR/.gitmodules" ]]; then
        info "Initializing crush submodule..."
        git -C "$DOTFILES_DIR" submodule update --init --recursive crush
    else
        info "Cloning crush source into $CRUSH_DIR ..."
        git clone "$CRUSH_REPO_URL" "$CRUSH_DIR"
    fi

    [[ -f "$CRUSH_DIR/go.mod" && -f "$CRUSH_DIR/main.go" ]]
}

install_crush() {
    echo
    info "=== Crush Setup ==="
    echo

    if [[ -x "$CRUSH_BINARY" ]]; then
        success "crush already built at $CRUSH_BINARY"
        "$CRUSH_BINARY" --version 2>/dev/null || true
        read -rp "Rebuild crush? [y/N] " answer
        answer="${answer:-N}"
        if [[ ! "$answer" =~ ^[Yy]$ ]]; then
            return 0
        fi
    else
        read -rp "Build crush and link it into $CRUSH_LINK? [Y/n] " answer
        answer="${answer:-Y}"
        if [[ ! "$answer" =~ ^[Yy]$ ]]; then
            warn "Skipping crush installation"
            return 0
        fi
    fi

    if ! command -v go &>/dev/null; then
        warn "Go is required to build crush."
        warn "Install Go first with: bash $DOTFILES_DIR/install/go.sh"
        return 1
    fi

    _ensure_crush_source || {
        warn "crush source is unavailable"
        return 1
    }

    mkdir -p "$CRUSH_BIN_DIR" "$DOTFILES_DIR/bin"

    info "Building crush from $CRUSH_DIR ..."
    if ! bash -lc "cd \"$CRUSH_DIR\" && CGO_ENABLED=0 GOEXPERIMENT=greenteagc go build -o \"$CRUSH_BINARY\" ."; then
        warn "crush build failed"
        return 1
    fi

    ln -sfn "$CRUSH_BINARY" "$CRUSH_LINK"

    if [[ -x "$CRUSH_BINARY" && -L "$CRUSH_LINK" ]]; then
        success "crush built at $CRUSH_BINARY"
        success "Linked $CRUSH_LINK -> $CRUSH_BINARY"
    else
        warn "crush installation may have failed"
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]:-$0}" == "$0" ]]; then
    install_crush
    ensure_bashrc
    hint_source_bashrc
fi
