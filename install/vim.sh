#!/usr/bin/env bash
# install/vim.sh - Symlink ~/.vimrc to the dotfiles-managed vim config.

if [[ -z "${BASH_VERSION:-}" ]]; then
    exec bash "$0" "$@"
fi

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
source "$SCRIPT_DIR/_common.sh"

VIMRC_SRC="$DOTFILES_DIR/vim/vimrc"
VIMRC_DEST="$HOME/.vimrc"

install_vim() {
    echo
    info "=== Vim config setup ==="
    echo

    if [[ ! -f "$VIMRC_SRC" ]]; then
        warn "Missing tracked vimrc: $VIMRC_SRC"
        return 1
    fi

    if [[ -L "$VIMRC_DEST" && "$(readlink "$VIMRC_DEST")" == "$VIMRC_SRC" ]]; then
        success "~/.vimrc already linked to $VIMRC_SRC"
    else
        if [[ -e "$VIMRC_DEST" || -L "$VIMRC_DEST" ]]; then
            local backup="${VIMRC_DEST}.bak.$(date +%Y%m%d%H%M%S)"
            mv "$VIMRC_DEST" "$backup"
            warn "Backed up existing ~/.vimrc -> $backup"
        fi
        ln -s "$VIMRC_SRC" "$VIMRC_DEST"
        success "Linked ~/.vimrc -> $VIMRC_SRC"
    fi

    if ! command -v xmllint >/dev/null 2>&1; then
        warn "xmllint not found; XML formatting (gg=G) needs it. On macOS it ships with the OS."
    fi

    echo
    info "Open a .xml file in vim and run gg=G (or <leader>x) to reformat it."
}

if [[ "${BASH_SOURCE[0]:-$0}" == "$0" ]]; then
    install_vim
fi
