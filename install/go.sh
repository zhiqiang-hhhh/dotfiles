#!/usr/bin/env bash
# install/go.sh - Install Go to ~/tools/go

set -euo pipefail

GO_VERSION="${GO_VERSION:-latest}"
TOOLS_DIR="$HOME/tools"
GO_INSTALL_DIR="$TOOLS_DIR/go"
GO_BIN_DIR="$GO_INSTALL_DIR/bin"
GO_URL="${GO_URL:-}"
GO_API_URL="https://go.dev/dl/?mode=json"

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

_resolve_download_url() {
    local target_version="$1"
    local arch="$2"
    local api_url="$3"

    python3 - "$target_version" "$arch" "$api_url" <<'PY'
import json
import sys
import urllib.request

target_version = sys.argv[1]
arch = sys.argv[2]
api_url = sys.argv[3]

with urllib.request.urlopen(api_url) as resp:
    data = json.load(resp)

if not isinstance(data, list) or not data:
    print("", end="")
    raise SystemExit(1)

if target_version == "latest":
    release = data[0]
else:
    wanted = target_version.strip()
    if not wanted.startswith("go"):
        wanted = "go" + wanted
    release = None
    for item in data:
        if item.get("version") == wanted:
            release = item
            break
    if not release:
        print("", end="")
        raise SystemExit(1)

wanted_name = f"{release.get('version')}.linux-{arch}.tar.gz"
for f in release.get("files", []):
    if (
        f.get("os") == "linux"
        and f.get("arch") == arch
        and f.get("kind") == "archive"
        and f.get("filename") == wanted_name
    ):
        print(f"https://go.dev/dl/{f['filename']}")
        raise SystemExit(0)

print("", end="")
raise SystemExit(1)
PY
}

install_go() {
    echo
    info "=== Go Setup (${GO_VERSION}) ==="
    echo

    if [[ -x "$GO_BIN_DIR/go" ]]; then
        success "Go already installed at $GO_BIN_DIR/go"
        "$GO_BIN_DIR/go" version || true
        read -rp "Reinstall Go? [y/N] " answer
        answer="${answer:-N}"
        if [[ ! "$answer" =~ ^[Yy]$ ]]; then
            return 0
        fi
    else
        read -rp "Install Go to $GO_INSTALL_DIR? [Y/n] " answer
        answer="${answer:-Y}"
        if [[ ! "$answer" =~ ^[Yy]$ ]]; then
            warn "Skipping Go installation"
            return 0
        fi
    fi

    local arch
    arch="$(_detect_arch)" || return 1

    if [[ -z "$GO_URL" ]]; then
        info "Resolving Go download URL..."
        if ! GO_URL="$(_resolve_download_url "$GO_VERSION" "$arch" "$GO_API_URL")"; then
            warn "Failed to resolve Go download URL from release metadata."
            warn "Set GO_URL manually and rerun this script."
            return 1
        fi
    fi

    local tmp_file
    tmp_file="/tmp/go-linux-${arch}-$$.tar.gz"

    info "Downloading Go package..."
    info "URL: $GO_URL"
    if command -v curl &>/dev/null; then
        if ! curl -fSL "$GO_URL" -o "$tmp_file"; then
            warn "Download failed."
            return 1
        fi
    elif command -v wget &>/dev/null; then
        if ! wget -q --show-progress "$GO_URL" -O "$tmp_file"; then
            warn "Download failed."
            return 1
        fi
    else
        warn "Neither curl nor wget found. Please install Go manually."
        return 1
    fi

    rm -rf "$GO_INSTALL_DIR"
    mkdir -p "$TOOLS_DIR"

    tar -xzf "$tmp_file" -C "$TOOLS_DIR"
    rm -f "$tmp_file"

    if [[ -x "$GO_BIN_DIR/go" ]]; then
        success "Go installed: $("$GO_BIN_DIR/go" version)"
    else
        warn "Go installation may have failed, binary not found"
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/_common.sh"

    install_go
    ensure_bashrc
    hint_source_bashrc
fi
