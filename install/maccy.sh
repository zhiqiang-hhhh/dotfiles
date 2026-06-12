#!/usr/bin/env bash
# install/maccy.sh - Install the Maccy clipboard manager.
#
# Installs the app only; set the popup hotkey yourself in
# Maccy > Settings > Hotkey (e.g. Shift+Cmd+H).

if [[ -z "${BASH_VERSION:-}" ]]; then
    exec bash "$0" "$@"
fi

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/_common.sh"

MACCY_APP="/Applications/Maccy.app"

install_maccy() {
    echo
    info "=== Maccy clipboard manager setup ==="
    echo

    if [[ "$(uname -s)" != "Darwin" ]]; then
        warn "Maccy is macOS-only; skipping on this platform"
        return 0
    fi

    if [[ -d "$MACCY_APP" ]]; then
        success "Maccy already installed: $MACCY_APP"
    elif command -v brew >/dev/null 2>&1; then
        info "Installing Maccy via Homebrew cask ..."
        brew install --cask maccy
        success "Installed Maccy"
    else
        warn "Homebrew not found; install Maccy manually:"
        warn "  brew install --cask maccy"
        warn "  (or download from https://github.com/p0deje/Maccy/releases)"
        return 1
    fi

    echo
    info "Next steps:"
    info "  1. Launch Maccy (open -a Maccy) and grant Accessibility permission if asked."
    info "  2. Set the popup hotkey in Maccy > Settings > Hotkey (e.g. Shift+Cmd+H)."
}

if [[ "${BASH_SOURCE[0]:-$0}" == "$0" ]]; then
    install_maccy
fi
