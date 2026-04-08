#!/usr/bin/env bash
# install/ripgrep.sh - Install ripgrep binary to ~/tools/ripgrep

if [[ -z "${BASH_VERSION:-}" ]]; then
    exec bash "$0" "$@"
fi

set -euo pipefail

RIPGREP_VERSION="${RIPGREP_VERSION:-latest}"
TOOLS_DIR="$HOME/tools"
RIPGREP_INSTALL_DIR="$TOOLS_DIR/ripgrep"
RIPGREP_BIN_DIR="$RIPGREP_INSTALL_DIR/bin"
RIPGREP_URL="${RIPGREP_URL:-}"
RIPGREP_API_URL="https://api.github.com/repos/BurntSushi/ripgrep/releases"

info()    { printf "\033[34m[INFO]\033[0m %s\n" "$1"; }
warn()    { printf "\033[33m[WARN]\033[0m %s\n" "$1"; }
success() { printf "\033[32m[ OK ]\033[0m %s\n" "$1"; }

_detect_arch() {
    local arch
    arch="$(uname -m)"
    case "$arch" in
        x86_64|amd64)
            echo "x86_64"
            ;;
        aarch64|arm64)
            echo "aarch64"
            ;;
        *)
            warn "Unsupported architecture: $arch"
            return 1
            ;;
    esac
}

_detect_os() {
    local os
    os="$(uname -s)"
    case "$os" in
        Linux)
            echo "unknown-linux-musl"
            ;;
        Darwin)
            echo "apple-darwin"
            ;;
        *)
            warn "Unsupported OS: $os"
            return 1
            ;;
    esac
}

_resolve_download_url() {
    local target_version="$1"
    local arch="$2"
    local os_suffix="$3"
    local api_url="$4"

    python3 - "$target_version" "$arch" "$os_suffix" "$api_url" <<'PY'
import json
import sys
import urllib.request

target_version = sys.argv[1]
arch = sys.argv[2]
os_suffix = sys.argv[3]
api_url = sys.argv[4]

with urllib.request.urlopen(api_url) as resp:
    data = json.load(resp)

release = None
if target_version == "latest":
    for item in data:
        if not item.get("draft") and not item.get("prerelease"):
            release = item
            break
else:
    wanted = target_version if target_version.startswith("v") else f"v{target_version}"
    for item in data:
        if item.get("tag_name") == wanted:
            release = item
            break

if not release:
    raise SystemExit(1)

wanted_name = f"ripgrep-{release['tag_name'].lstrip('v')}-{arch}-{os_suffix}.tar.gz"
for asset in release.get("assets", []):
    if asset.get("name") == wanted_name:
        print(asset.get("browser_download_url", ""))
        raise SystemExit(0)

raise SystemExit(1)
PY
}

install_ripgrep() {
    echo
    info "=== ripgrep Setup (${RIPGREP_VERSION}) ==="
    echo

    if [[ -x "$RIPGREP_BIN_DIR/rg" ]]; then
        success "ripgrep already installed at $RIPGREP_BIN_DIR/rg"
        "$RIPGREP_BIN_DIR/rg" --version | sed -n '1p' || true
        read -rp "Reinstall ripgrep? [y/N] " answer
        answer="${answer:-N}"
        if [[ ! "$answer" =~ ^[Yy]$ ]]; then
            return 0
        fi
    else
        read -rp "Install ripgrep to $RIPGREP_INSTALL_DIR? [Y/n] " answer
        answer="${answer:-Y}"
        if [[ ! "$answer" =~ ^[Yy]$ ]]; then
            warn "Skipping ripgrep installation"
            return 0
        fi
    fi

    local arch
    local os_suffix
    local tmp_file
    local tmp_dir
    arch="$(_detect_arch)" || return 1
    os_suffix="$(_detect_os)" || return 1

    if [[ -z "$RIPGREP_URL" ]]; then
        info "Resolving ripgrep download URL..."
        if ! RIPGREP_URL="$(_resolve_download_url "$RIPGREP_VERSION" "$arch" "$os_suffix" "$RIPGREP_API_URL")"; then
            warn "Failed to resolve ripgrep download URL. Set RIPGREP_URL manually and rerun."
            return 1
        fi
    fi

    tmp_file="/tmp/ripgrep-${arch}-$$.tar.gz"
    tmp_dir="$(mktemp -d)"

    info "Downloading ripgrep package..."
    info "URL: $RIPGREP_URL"
    if command -v curl &>/dev/null; then
        curl -fSL "$RIPGREP_URL" -o "$tmp_file" || {
            rm -rf "$tmp_dir"
            warn "Download failed."
            return 1
        }
    elif command -v wget &>/dev/null; then
        wget -q --show-progress "$RIPGREP_URL" -O "$tmp_file" || {
            rm -rf "$tmp_dir"
            warn "Download failed."
            return 1
        }
    else
        rm -rf "$tmp_dir"
        warn "Neither curl nor wget found. Please install ripgrep manually."
        return 1
    fi

    rm -rf "$RIPGREP_INSTALL_DIR"
    mkdir -p "$RIPGREP_BIN_DIR"
    tar -xzf "$tmp_file" -C "$tmp_dir"

    local candidate=""
    for candidate in "$tmp_dir"/ripgrep-*/rg "$tmp_dir"/*/rg "$tmp_dir"/rg; do
        if [[ -f "$candidate" ]]; then
            install -m 755 "$candidate" "$RIPGREP_BIN_DIR/rg"
            break
        fi
    done

    rm -f "$tmp_file"
    rm -rf "$tmp_dir"

    if [[ -x "$RIPGREP_BIN_DIR/rg" ]]; then
        success "ripgrep installed: $($RIPGREP_BIN_DIR/rg --version | sed -n '1p')"
    else
        warn "ripgrep installation may have failed, binary not found"
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]:-$0}" == "$0" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
    source "$SCRIPT_DIR/_common.sh"

    install_ripgrep
    ensure_bashrc
    hint_source_bashrc
fi
