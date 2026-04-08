#!/usr/bin/env bash
# install/java.sh - Install JDK 17 to ~/tools/jdk

if [[ -z "${BASH_VERSION:-}" ]]; then
    exec bash "$0" "$@"
fi

set -euo pipefail

JAVA_VERSION="${JAVA_VERSION:-17}"
TOOLS_DIR="$HOME/tools"
JAVA_INSTALL_DIR="$TOOLS_DIR/jdk"
JAVA_URL="${JAVA_URL:-}"

info()    { printf "\033[34m[INFO]\033[0m %s\n" "$1"; }
warn()    { printf "\033[33m[WARN]\033[0m %s\n" "$1"; }
success() { printf "\033[32m[ OK ]\033[0m %s\n" "$1"; }

install_java() {
    echo
    info "=== JDK 17 Setup ==="
    echo

    # Check if java 17 is already available
    if command -v java &>/dev/null; then
        local java_ver
        java_ver="$(java -version 2>&1 | head -1)"
        if echo "$java_ver" | grep -q '"17\.' ; then
            success "JDK 17 is already installed: $java_ver"
            return 0
        else
            info "Java found but not version 17: $java_ver"
        fi
    fi

    read -rp "Install JDK 17? [Y/n] " answer
    answer="${answer:-Y}"
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        warn "Skipping JDK 17 installation"
        return 0
    fi

    local arch os_name tmp_file tmp_dir extracted_dir java_home
    arch="$(uname -m)"
    os_name="$(uname -s)"
    case "$arch" in
        x86_64|amd64) arch="x64" ;;
        aarch64|arm64) arch="aarch64" ;;
        *)
            warn "Unsupported architecture: $arch"
            return 1
            ;;
    esac
    case "$os_name" in
        Linux) os_name="linux" ;;
        Darwin) os_name="mac" ;;
        *)
            warn "Unsupported OS: $os_name"
            return 1
            ;;
    esac

    if [[ -z "$JAVA_URL" ]]; then
        JAVA_URL="$(python3 - "$JAVA_VERSION" "$arch" "$os_name" <<'PY'
import json
import sys
import urllib.request

version, arch, os_name = sys.argv[1:4]
url = f"https://api.adoptium.net/v3/assets/latest/{version}/hotspot?architecture={arch}&heap_size=normal&image_type=jdk&jvm_impl=hotspot&os={os_name}&project=jdk"
with urllib.request.urlopen(url) as resp:
    data = json.load(resp)
pkg = data[0]["binary"]["package"]["link"]
print(pkg)
PY
)" || {
            warn "Failed to resolve JDK download URL."
            return 1
        }
    fi

    tmp_file="/tmp/jdk-${arch}-$$.tar.gz"
    tmp_dir="$(mktemp -d)"

    info "Downloading JDK package..."
    info "URL: $JAVA_URL"
    if command -v curl &>/dev/null; then
        curl -fSL "$JAVA_URL" -o "$tmp_file" || {
            rm -rf "$tmp_dir"
            warn "Download failed."
            return 1
        }
    elif command -v wget &>/dev/null; then
        wget -q --show-progress "$JAVA_URL" -O "$tmp_file" || {
            rm -rf "$tmp_dir"
            warn "Download failed."
            return 1
        }
    else
        rm -rf "$tmp_dir"
        warn "Neither curl nor wget found. Please install JDK manually."
        return 1
    fi

    mkdir -p "$TOOLS_DIR"
    rm -rf "$JAVA_INSTALL_DIR"
    tar -xzf "$tmp_file" -C "$tmp_dir"
    extracted_dir="$(printf '%s\n' "$tmp_dir"/* | sed -n '1p')"
    java_home="$extracted_dir"
    if [[ -d "$extracted_dir/Contents/Home" ]]; then
        java_home="$extracted_dir/Contents/Home"
    fi
    mv "$java_home" "$JAVA_INSTALL_DIR"
    rm -f "$tmp_file"
    rm -rf "$tmp_dir"

    # Verify installation
    if [[ -x "$JAVA_INSTALL_DIR/bin/java" ]]; then
        success "JDK 17 installed: $($JAVA_INSTALL_DIR/bin/java -version 2>&1 | sed -n '1p')"
    else
        warn "Java command not found after installation, check your PATH"
    fi

    info "JAVA_HOME will resolve to: $JAVA_INSTALL_DIR"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]:-$0}" == "$0" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
    source "$SCRIPT_DIR/_common.sh"

    install_java
    ensure_bashrc
    hint_source_bashrc
fi
