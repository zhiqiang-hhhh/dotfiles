#!/usr/bin/env bash
# install/iterm2.sh - Configure iTerm2 to load settings from this dotfiles repo

if [[ -z "${BASH_VERSION:-}" ]]; then
    exec bash "$0" "$@"
fi

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
source "$SCRIPT_DIR/_common.sh"

ITERM2_SETTINGS_DIR="$DOTFILES_DIR/iterm2/settings"
ITERM2_SETTINGS_PLIST="$ITERM2_SETTINGS_DIR/com.googlecode.iterm2.plist"
ITERM2_LOCAL_PLIST="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
ITERM2_OLD_DYNAMIC_PROFILE_LINK="$HOME/Library/Application Support/iTerm2/DynamicProfiles/dotfiles.json"
ITERM2_OLD_DYNAMIC_PROFILE_TARGET="$DOTFILES_DIR/iterm2/DynamicProfiles/dotfiles.json"

install_iterm2() {
    echo
    info "=== iTerm2 Custom Settings Folder Setup ==="
    echo

    if [[ "$(uname -s)" != "Darwin" ]]; then
        warn "iTerm2 is macOS-only; skipping on this platform"
        return 0
    fi

    mkdir -p "$ITERM2_SETTINGS_DIR"

    if [[ ! -f "$ITERM2_SETTINGS_PLIST" ]]; then
        if [[ ! -f "$ITERM2_LOCAL_PLIST" ]]; then
            warn "iTerm2 settings plist not found: $ITERM2_SETTINGS_PLIST"
            warn "Open iTerm2 once or add the tracked settings plist, then rerun this installer"
            return 1
        fi

        info "Initializing tracked iTerm2 settings from current local preferences"
        cp "$ITERM2_LOCAL_PLIST" "$ITERM2_SETTINGS_PLIST"
        plutil -convert xml1 "$ITERM2_SETTINGS_PLIST"
    fi

    plutil -lint "$ITERM2_SETTINGS_PLIST" >/dev/null

    /usr/libexec/PlistBuddy -c "Set :LoadPrefsFromCustomFolder true" "$ITERM2_SETTINGS_PLIST" 2>/dev/null \
        || /usr/libexec/PlistBuddy -c "Add :LoadPrefsFromCustomFolder bool true" "$ITERM2_SETTINGS_PLIST"
    /usr/libexec/PlistBuddy -c "Set :PrefsCustomFolder $ITERM2_SETTINGS_DIR" "$ITERM2_SETTINGS_PLIST" 2>/dev/null \
        || /usr/libexec/PlistBuddy -c "Add :PrefsCustomFolder string $ITERM2_SETTINGS_DIR" "$ITERM2_SETTINGS_PLIST"

    if [[ -L "$ITERM2_OLD_DYNAMIC_PROFILE_LINK" ]]; then
        local current_target
        current_target="$(readlink "$ITERM2_OLD_DYNAMIC_PROFILE_LINK")"
        if [[ "$current_target" == "$ITERM2_OLD_DYNAMIC_PROFILE_TARGET" || "$ITERM2_OLD_DYNAMIC_PROFILE_LINK" -ef "$ITERM2_OLD_DYNAMIC_PROFILE_TARGET" ]]; then
            unlink "$ITERM2_OLD_DYNAMIC_PROFILE_LINK"
            info "Removed old dotfiles-managed iTerm2 Dynamic Profile symlink"
        fi
    fi

    defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
    defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$ITERM2_SETTINGS_DIR"

    success "Configured iTerm2 to load settings from $ITERM2_SETTINGS_DIR"
    info "Restart iTerm2 so it reloads settings from the custom folder."
    info "In iTerm2 Settings > General > Settings, keep 'Save changes to folder when iTerm2 quits' enabled."
}

if [[ "${BASH_SOURCE[0]:-$0}" == "$0" ]]; then
    install_iterm2
fi
