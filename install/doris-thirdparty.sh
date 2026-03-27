#!/usr/bin/env bash
#
# install/doris-thirdparty.sh - Download prebuilt Doris thirdparty dependencies
#
# Downloads the correct prebuilt archive from apache/doris-thirdparty releases
# and symlinks it into the doris source tree.
#
# Usage:
#   bash install/doris-thirdparty.sh          # standalone
#   source install/doris-thirdparty.sh        # then call install_doris_thirdparty
#
# Requirements:
#   - ~/code/doris must exist (cloned first)
#   - curl, tar, xz must be available
#
# Result:
#   ~/downloads/doris-thirdparty/installed/    - extracted prebuilt libs
#   ~/code/doris/thirdparty/installed          - symlink -> above
#

set -euo pipefail

# Helper functions (standalone-safe: only define if not already defined)
if ! declare -f info &>/dev/null; then
    info()    { printf "\033[34m[INFO]\033[0m %s\n" "$1"; }
    warn()    { printf "\033[33m[WARN]\033[0m %s\n" "$1"; }
    success() { printf "\033[32m[ OK ]\033[0m %s\n" "$1"; }
    error()   { printf "\033[31m[ERR ]\033[0m %s\n" "$1"; }
fi

install_doris_thirdparty() {
    local doris_dir="$HOME/code/doris"
    local download_dir="$HOME/downloads"
    local thirdparty_dir="$download_dir/doris-thirdparty"
    local symlink_target="$doris_dir/thirdparty/installed"

    # ---- Pre-checks ----

    if [[ ! -d "$doris_dir" ]]; then
        warn "Doris source tree not found at $doris_dir"
        warn "Clone it first: git clone git@github.com:zhiqiang-hhhh/doris.git $doris_dir"
        return 0
    fi

    # Check if symlink already points to a valid directory
    if [[ -L "$symlink_target" && -d "$symlink_target" ]]; then
        success "Doris thirdparty already installed: $symlink_target -> $(readlink -f "$symlink_target")"
        return 0
    fi

    # Check if thirdparty was already extracted (but symlink missing/broken)
    if [[ -d "$thirdparty_dir/installed" ]]; then
        info "Thirdparty already extracted at $thirdparty_dir, creating symlink..."
        _create_thirdparty_symlink "$symlink_target" "$thirdparty_dir/installed"
        return 0
    fi

    # ---- Detect platform ----

    local os arch filename
    os="$(uname -s)"
    arch="$(uname -m)"

    case "$os" in
        Linux)
            case "$arch" in
                x86_64)
                    filename="doris-thirdparty-prebuilt-linux-x86_64.tar.xz"
                    ;;
                aarch64|arm64)
                    # Note: upstream uses "prebuild" (not "prebuilt") for arm64
                    filename="doris-thirdparty-prebuild-arm64.tar.xz"
                    ;;
                *)
                    error "Unsupported Linux architecture: $arch"
                    return 0
                    ;;
            esac
            ;;
        Darwin)
            case "$arch" in
                x86_64)
                    filename="doris-thirdparty-prebuilt-darwin-x86_64.tar.xz"
                    ;;
                arm64|aarch64)
                    filename="doris-thirdparty-prebuilt-darwin-arm64.tar.xz"
                    ;;
                *)
                    error "Unsupported macOS architecture: $arch"
                    return 0
                    ;;
            esac
            ;;
        *)
            error "Unsupported OS: $os"
            return 0
            ;;
    esac

    local download_url="https://github.com/apache/doris-thirdparty/releases/download/automation/${filename}"
    local archive_path="$download_dir/$filename"

    info "Platform: $os $arch"
    info "Archive:  $filename"
    info "URL:      $download_url"

    # ---- Ensure directories exist ----

    mkdir -p "$download_dir"
    mkdir -p "$doris_dir/thirdparty"

    # ---- Download ----

    if [[ -f "$archive_path" ]]; then
        info "Archive already downloaded: $archive_path"
    else
        info "Downloading doris-thirdparty (this may take a while)..."
        if ! curl -fSL --progress-bar -o "$archive_path.tmp" "$download_url"; then
            rm -f "$archive_path.tmp"
            error "Download failed: $download_url"
            return 0
        fi
        mv "$archive_path.tmp" "$archive_path"
        success "Downloaded: $archive_path"
    fi

    # ---- Extract ----

    info "Extracting to $thirdparty_dir ..."
    mkdir -p "$thirdparty_dir"

    if ! tar -xJf "$archive_path" -C "$thirdparty_dir"; then
        error "Extraction failed"
        return 0
    fi

    # Verify the expected directory exists after extraction
    if [[ ! -d "$thirdparty_dir/installed" ]]; then
        # Some archives may extract into a subdirectory — try to find it
        local extracted_installed
        extracted_installed="$(find "$thirdparty_dir" -maxdepth 2 -type d -name "installed" | head -1)"
        if [[ -n "$extracted_installed" ]]; then
            info "Found installed dir at: $extracted_installed"
            # Move it to the expected location if it's nested
            if [[ "$extracted_installed" != "$thirdparty_dir/installed" ]]; then
                mv "$extracted_installed" "$thirdparty_dir/installed"
            fi
        else
            error "Could not find 'installed' directory after extraction"
            error "Check contents: ls $thirdparty_dir"
            return 0
        fi
    fi

    success "Extracted doris-thirdparty"

    # ---- Symlink ----

    _create_thirdparty_symlink "$symlink_target" "$thirdparty_dir/installed"

    # ---- Cleanup hint ----

    local archive_size
    archive_size="$(du -sh "$archive_path" 2>/dev/null | cut -f1)"
    info "Archive ($archive_size) kept at: $archive_path"
    info "To reclaim space: rm $archive_path"
}

_create_thirdparty_symlink() {
    local symlink_path="$1"
    local target_path="$2"

    # Remove existing symlink or directory if present
    if [[ -L "$symlink_path" ]]; then
        rm -f "$symlink_path"
    elif [[ -d "$symlink_path" ]]; then
        warn "Existing directory at $symlink_path — backing up"
        mv "$symlink_path" "${symlink_path}.bak.$(date +%Y%m%d%H%M%S)"
    fi

    ln -s "$target_path" "$symlink_path"
    success "Symlink created: $symlink_path -> $target_path"
}

# ---- Standalone execution ----

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/_common.sh"

    install_doris_thirdparty
    ensure_bashrc
    hint_source_bashrc
fi
