#!/usr/bin/env bash
# install/rclone.sh - Install rclone binary to ~/tools/rclone

set -euo pipefail

RCLONE_VERSION="${RCLONE_VERSION:-latest}"
TOOLS_DIR="$HOME/tools"
RCLONE_INSTALL_DIR="$TOOLS_DIR/rclone"
RCLONE_BIN_DIR="$RCLONE_INSTALL_DIR/bin"
RCLONE_URL="${RCLONE_URL:-}"

info()    { printf "\033[34m[INFO]\033[0m %s\n" "$1"; }
warn()    { printf "\033[33m[WARN]\033[0m %s\n" "$1"; }
success() { printf "\033[32m[ OK ]\033[0m %s\n" "$1"; }

_detect_arch() {
    local arch
    arch="$(uname -m)"
    case "$arch" in
        x86_64|amd64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        *)
            warn "Unsupported architecture: $arch"
            return 1
            ;;
    esac
}

_default_url() {
    local arch="$1"
    if [[ "$RCLONE_VERSION" == "latest" ]]; then
        echo "https://downloads.rclone.org/rclone-current-linux-${arch}.zip"
    else
        echo "https://downloads.rclone.org/${RCLONE_VERSION}/rclone-${RCLONE_VERSION}-linux-${arch}.zip"
    fi
}

install_rclone() {
    echo
    info "=== rclone Setup (${RCLONE_VERSION}) ==="
    echo

    if [[ -x "$RCLONE_BIN_DIR/rclone" ]]; then
        success "rclone already installed at $RCLONE_BIN_DIR/rclone"
        "$RCLONE_BIN_DIR/rclone" version | head -1 || true
        read -rp "Reinstall rclone? [y/N] " answer
        answer="${answer:-N}"
        if [[ ! "$answer" =~ ^[Yy]$ ]]; then
            return 0
        fi
    else
        read -rp "Install rclone to $RCLONE_INSTALL_DIR? [Y/n] " answer
        answer="${answer:-Y}"
        if [[ ! "$answer" =~ ^[Yy]$ ]]; then
            warn "Skipping rclone installation"
            return 0
        fi
    fi

    local arch
    arch="$(_detect_arch)" || return 1

    if [[ -z "$RCLONE_URL" ]]; then
        RCLONE_URL="$(_default_url "$arch")"
    fi

    local tmp_file
    local tmp_dir
    tmp_file="/tmp/rclone-${arch}-$$"
    tmp_dir="$(mktemp -d)"

    info "Downloading rclone package..."
    info "URL: $RCLONE_URL"
    if command -v curl &>/dev/null; then
        if ! curl -fSL "$RCLONE_URL" -o "$tmp_file"; then
            warn "Download failed from default URL."
            warn "Set RCLONE_URL to the exact package URL and rerun."
            rm -rf "$tmp_dir"
            return 1
        fi
    elif command -v wget &>/dev/null; then
        if ! wget -q --show-progress "$RCLONE_URL" -O "$tmp_file"; then
            warn "Download failed from default URL."
            warn "Set RCLONE_URL to the exact package URL and rerun."
            rm -rf "$tmp_dir"
            return 1
        fi
    else
        warn "Neither curl nor wget found. Please install rclone manually."
        rm -rf "$tmp_dir"
        return 1
    fi

    rm -rf "$RCLONE_INSTALL_DIR"
    mkdir -p "$RCLONE_BIN_DIR"

    case "$RCLONE_URL" in
        *.zip)
            if command -v unzip &>/dev/null; then
                unzip -oq "$tmp_file" -d "$tmp_dir"
            else
                warn "Archive is zip but unzip is not installed."
                rm -f "$tmp_file"
                rm -rf "$tmp_dir"
                return 1
            fi
            ;;
        *.tar.gz|*.tgz)
            tar -xzf "$tmp_file" -C "$tmp_dir"
            ;;
        *)
            install -m 755 "$tmp_file" "$RCLONE_BIN_DIR/rclone"
            ;;
    esac

    if [[ ! -x "$RCLONE_BIN_DIR/rclone" ]]; then
        local candidate
        for candidate in \
            "$tmp_dir/rclone" \
            "$tmp_dir"/*/rclone \
            "$tmp_dir"/*/*/rclone
        do
            if [[ -f "$candidate" ]]; then
                install -m 755 "$candidate" "$RCLONE_BIN_DIR/rclone"
                break
            fi
        done
    fi

    rm -f "$tmp_file"
    rm -rf "$tmp_dir"

    if [[ -x "$RCLONE_BIN_DIR/rclone" ]]; then
        success "rclone installed: $RCLONE_BIN_DIR/rclone"
        "$RCLONE_BIN_DIR/rclone" version | head -1 || true
    else
        warn "rclone installation may have failed, binary not found"
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/_common.sh"

    install_rclone
    ensure_bashrc
    hint_source_bashrc
fi
