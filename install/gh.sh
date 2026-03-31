#!/usr/bin/env bash
# install/gh.sh - Install GitHub CLI binary to ~/tools/github-cli

set -euo pipefail

GH_VERSION="${GH_VERSION:-latest}"
TOOLS_DIR="$HOME/tools"
GH_INSTALL_DIR="$TOOLS_DIR/github-cli"
GH_BIN_DIR="$GH_INSTALL_DIR/bin"
GH_URL="${GH_URL:-}"
GH_API_URL="https://api.github.com/repos/cli/cli/releases"

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

_detect_os() {
    local os
    os="$(uname -s)"
    case "$os" in
        Linux)
            echo "linux"
            ;;
        Darwin)
            echo "macOS"
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
    local os="$3"
    local api_url="$4"

    python3 - "$target_version" "$arch" "$os" "$api_url" <<'PY'
import json
import sys
import urllib.request

target_version = sys.argv[1]
arch = sys.argv[2]
os_name = sys.argv[3]
api_url = sys.argv[4]

with urllib.request.urlopen(api_url) as resp:
    data = json.load(resp)

if not isinstance(data, list) or not data:
    print("", end="")
    raise SystemExit(1)

release = None
if target_version == "latest":
    for item in data:
        if not item.get("draft") and not item.get("prerelease"):
            release = item
            break
else:
    wanted = target_version
    if not wanted.startswith("v"):
        wanted = "v" + wanted
    for item in data:
        if item.get("tag_name") == wanted:
            release = item
            break

if not release:
    print("", end="")
    raise SystemExit(1)

wanted_suffixes = [f"{os_name}_{arch}.tar.gz", f"{os_name}_{arch}.zip"]
for asset in release.get("assets", []):
    name = asset.get("name", "")
    if name.startswith("gh_") and any(name.endswith(suffix) for suffix in wanted_suffixes):
        print(asset.get("browser_download_url", ""))
        raise SystemExit(0)

print("", end="")
raise SystemExit(1)
PY
}

install_gh() {
    echo
    info "=== GitHub CLI (gh) Setup (${GH_VERSION}) ==="
    echo

    if [[ -x "$GH_BIN_DIR/gh" ]]; then
        success "gh already installed at $GH_BIN_DIR/gh"
        "$GH_BIN_DIR/gh" --version || true
        read -rp "Reinstall gh? [y/N] " answer
        answer="${answer:-N}"
        if [[ ! "$answer" =~ ^[Yy]$ ]]; then
            return 0
        fi
    else
        read -rp "Install gh to $GH_INSTALL_DIR? [Y/n] " answer
        answer="${answer:-Y}"
        if [[ ! "$answer" =~ ^[Yy]$ ]]; then
            warn "Skipping gh installation"
            return 0
        fi
    fi

    local arch
    local os
    os="$(_detect_os)" || return 1
    arch="$(_detect_arch)" || return 1

    if [[ -z "$GH_URL" ]]; then
        info "Resolving GitHub CLI download URL..."
        if ! GH_URL="$(_resolve_download_url "$GH_VERSION" "$arch" "$os" "$GH_API_URL")"; then
            warn "Failed to resolve gh download URL from GitHub release metadata."
            warn "Set GH_URL manually and rerun this script."
            return 1
        fi
    fi

    local tmp_file
    local tmp_dir
    tmp_file="/tmp/gh-${os}-${arch}-$$"
    tmp_dir="$(mktemp -d)"

    info "Downloading gh package..."
    info "URL: $GH_URL"
    if command -v curl &>/dev/null; then
        if ! curl -fSL "$GH_URL" -o "$tmp_file"; then
            warn "Download failed."
            rm -rf "$tmp_dir"
            return 1
        fi
    elif command -v wget &>/dev/null; then
        if ! wget -q --show-progress "$GH_URL" -O "$tmp_file"; then
            warn "Download failed."
            rm -rf "$tmp_dir"
            return 1
        fi
    else
        warn "Neither curl nor wget found. Please install gh manually."
        rm -rf "$tmp_dir"
        return 1
    fi

    rm -rf "$GH_INSTALL_DIR"
    mkdir -p "$GH_BIN_DIR"

    if [[ "$GH_URL" == *.tar.gz ]]; then
        tar -xzf "$tmp_file" -C "$tmp_dir"
    elif [[ "$GH_URL" == *.zip ]]; then
        if command -v unzip &>/dev/null; then
            unzip -oq "$tmp_file" -d "$tmp_dir"
        else
            warn "Archive is zip but unzip is not installed."
            rm -f "$tmp_file"
            rm -rf "$tmp_dir"
            return 1
        fi
    else
        warn "Unexpected package format: $GH_URL"
        rm -f "$tmp_file"
        rm -rf "$tmp_dir"
        return 1
    fi

    local candidate=""
    for candidate in \
        "$tmp_dir"/gh_*/bin/gh \
        "$tmp_dir"/*/bin/gh \
        "$tmp_dir"/gh
    do
        if [[ -f "$candidate" ]]; then
            install -m 755 "$candidate" "$GH_BIN_DIR/gh"
            break
        fi
    done

    rm -f "$tmp_file"
    rm -rf "$tmp_dir"

    if [[ -x "$GH_BIN_DIR/gh" ]]; then
        success "gh installed: $GH_BIN_DIR/gh"
        "$GH_BIN_DIR/gh" --version || true
    else
        warn "gh installation may have failed, binary not found"
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/_common.sh"

    install_gh
    ensure_bashrc
    hint_source_bashrc
fi
