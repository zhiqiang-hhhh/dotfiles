#!/usr/bin/env bash
# install/ldb_toolchain.sh - Download and install ldb_toolchain_gen

if [[ -z "${BASH_VERSION:-}" ]]; then
    exec bash "$0" "$@"
fi

set -euo pipefail

LDB_VERSION="${LDB_VERSION:-v0.26}"
TOOLS_DIR="$HOME/tools"
LDB_INSTALL_DIR="$TOOLS_DIR/ldb_toolchain"

info()    { printf "\033[34m[INFO]\033[0m %s\n" "$1"; }
warn()    { printf "\033[33m[WARN]\033[0m %s\n" "$1"; }
success() { printf "\033[32m[ OK ]\033[0m %s\n" "$1"; }

install_ldb_toolchain() {
    echo
    info "=== ldb_toolchain Setup (${LDB_VERSION}) ==="
    echo

    local os
    os="$(uname -s)"
    if [[ "$os" == "Darwin" ]]; then
        warn "ldb_toolchain installer is Linux-focused and is not supported on macOS."
        warn "Skipping ldb_toolchain installation on macOS."
        return 0
    fi

    # Check if already installed (directory exists and has gcc binary)
    if [[ -x "$LDB_INSTALL_DIR/bin/gcc" ]]; then
        success "ldb_toolchain already installed at $LDB_INSTALL_DIR"
        info "gcc version: $("$LDB_INSTALL_DIR/bin/gcc" --version | head -1)"
        return 0
    fi

    # If directory exists but is incomplete, remove it so gen.sh can recreate
    if [[ -d "$LDB_INSTALL_DIR" ]]; then
        warn "Directory $LDB_INSTALL_DIR exists but appears incomplete (no bin/gcc)"
        read -rp "Remove and reinstall? [Y/n] " answer
        answer="${answer:-Y}"
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            rm -rf "$LDB_INSTALL_DIR"
            info "Removed $LDB_INSTALL_DIR"
        else
            warn "Skipping ldb_toolchain installation"
            return 0
        fi
    else
        read -rp "Install ldb_toolchain ${LDB_VERSION} to $LDB_INSTALL_DIR? [Y/n] " answer
        answer="${answer:-Y}"
        if [[ ! "$answer" =~ ^[Yy]$ ]]; then
            warn "Skipping ldb_toolchain installation"
            return 0
        fi
    fi

    # Detect CPU architecture and choose the correct download filename
    local arch
    arch="$(uname -m)"
    local gen_filename="ldb_toolchain_gen.sh"
    if [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
        gen_filename="ldb_toolchain_gen_aarch64.sh"
    fi

    local ldb_url="https://github.com/amosbird/ldb_toolchain_gen/releases/download/${LDB_VERSION}/${gen_filename}"
    local tmp_file="/tmp/${gen_filename}"

    info "Detected architecture: $arch"
    info "Downloading ${gen_filename} (${LDB_VERSION})..."
    info "URL: $ldb_url"
    info "This may take a while (file is ~300 MB)..."
    if command -v curl &>/dev/null; then
        curl -fSL "$ldb_url" -o "$tmp_file"
    elif command -v wget &>/dev/null; then
        wget -q --show-progress "$ldb_url" -O "$tmp_file"
    else
        warn "Neither curl nor wget found. Please download manually."
        return 0
    fi

    chmod +x "$tmp_file"

    # NOTE: Do NOT mkdir the target dir — ldb_toolchain_gen.sh expects to create it itself
    # and will error if it already exists.
    info "Running ${gen_filename} (installing to $LDB_INSTALL_DIR)..."
    if bash "$tmp_file" "$LDB_INSTALL_DIR"; then
        info "${gen_filename} completed"
    else
        warn "${gen_filename} exited with non-zero status"
    fi

    rm -f "$tmp_file"

    if [[ -x "$LDB_INSTALL_DIR/bin/gcc" ]]; then
        success "ldb_toolchain installed successfully!"
        info "gcc: $("$LDB_INSTALL_DIR/bin/gcc" --version | head -1)"
        info "g++: $("$LDB_INSTALL_DIR/bin/g++" --version | head -1)"
    else
        warn "ldb_toolchain installation may have failed, check $LDB_INSTALL_DIR"
    fi

    # Warn about LD_LIBRARY_PATH (per upstream FAQ: it must NOT be set)
    if [[ -n "${LD_LIBRARY_PATH:-}" ]]; then
        echo
        warn "LD_LIBRARY_PATH is currently set: $LD_LIBRARY_PATH"
        warn "The ldb_toolchain FAQ states: LD_LIBRARY_PATH must NOT be set,"
        warn "otherwise the compiler/linker may fail with 'Symbol not found' errors."
        warn "Consider unsetting it:  unset LD_LIBRARY_PATH"
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]:-$0}" == "$0" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
    source "$SCRIPT_DIR/_common.sh"

    install_ldb_toolchain
    ensure_bashrc
    hint_source_bashrc
fi
