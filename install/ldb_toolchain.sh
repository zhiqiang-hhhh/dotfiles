#!/usr/bin/env bash
# install/ldb_toolchain.sh - Download and install ldb_toolchain_gen
#
# Usage:
#   bash install/ldb_toolchain.sh [version]
#
#   version   release tag to install, e.g. v0.25. If omitted (and LDB_VERSION
#             is unset) the latest GitHub release is used.
#
# Versions install side-by-side under ~/tools/ldb_toolchain/versions/<version>
# and the freshly installed one becomes "current". Switch later with: use-ldb

if [[ -z "${BASH_VERSION:-}" ]]; then
    exec bash "$0" "$@"
fi

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"
source "$DOTFILES_DIR/bin/_ldb-common.sh"

info()    { printf "\033[34m[INFO]\033[0m %s\n" "$1"; }
warn()    { printf "\033[33m[WARN]\033[0m %s\n" "$1"; }
success() { printf "\033[32m[ OK ]\033[0m %s\n" "$1"; }

# Resolve which version to install: explicit arg > LDB_VERSION env > latest > fallback.
_ldb_resolve_version() {
    local requested="${1:-${LDB_VERSION:-}}"
    if [[ -n "$requested" ]]; then
        printf '%s\n' "$requested"
        return 0
    fi

    info "No version specified; querying the latest release ..." >&2
    local latest
    if latest="$(ldb_latest_version)"; then
        info "Latest release is ${latest}" >&2
        printf '%s\n' "$latest"
    else
        warn "Could not resolve the latest release; falling back to ${LDB_FALLBACK_VERSION}" >&2
        printf '%s\n' "$LDB_FALLBACK_VERSION"
    fi
}

install_ldb_toolchain() {
    local version
    version="$(_ldb_resolve_version "${1:-}")"

    echo
    info "=== ldb_toolchain Setup (${version}) ==="
    echo

    local os
    os="$(uname -s)"
    if [[ "$os" == "Darwin" ]]; then
        warn "ldb_toolchain installer is Linux-focused and is not supported on macOS."
        warn "Skipping ldb_toolchain installation on macOS."
        return 0
    fi

    local dest
    dest="$(ldb_version_dir "$version")"

    # Already installed? Just make sure it's the active version.
    if ldb_is_installed "$version"; then
        success "ldb_toolchain ${version} already installed at $dest"
        info "gcc version: $("$dest/bin/gcc" --version | head -1)"
        ldb_set_current "$version" && success "Active version is now ${version}"
        return 0
    fi

    # Incomplete leftover directory for this version: remove so gen.sh can recreate.
    if [[ -d "$dest" ]]; then
        warn "Directory $dest exists but appears incomplete (no bin/gcc)"
        read -rp "Remove and reinstall ${version}? [Y/n] " answer
        answer="${answer:-Y}"
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            rm -rf "$dest"
            info "Removed $dest"
        else
            warn "Skipping ldb_toolchain installation"
            return 0
        fi
    else
        read -rp "Install ldb_toolchain ${version} to $dest? [Y/n] " answer
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

    local ldb_url="https://github.com/${LDB_REPO}/releases/download/${version}/${gen_filename}"
    local tmp_file="/tmp/${gen_filename}"

    info "Detected architecture: $arch"
    info "Downloading ${gen_filename} (${version})..."
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

    # gen.sh creates the target dir itself and errors if it already exists,
    # so make only the parent (versions/) and hand it the non-existent dest.
    mkdir -p "$LDB_VERSIONS_DIR"
    info "Running ${gen_filename} (installing to $dest)..."
    if bash "$tmp_file" "$dest"; then
        info "${gen_filename} completed"
    else
        warn "${gen_filename} exited with non-zero status"
    fi

    rm -f "$tmp_file"

    if ldb_is_installed "$version"; then
        success "ldb_toolchain ${version} installed successfully!"
        info "gcc: $("$dest/bin/gcc" --version | head -1)"
        info "g++: $("$dest/bin/g++" --version | head -1)"
        ldb_set_current "$version" && success "Active version is now ${version} (switch with: use-ldb)"
    else
        warn "ldb_toolchain installation may have failed, check $dest"
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
    source "$SCRIPT_DIR/_common.sh"

    install_ldb_toolchain "$@"
    ensure_bashrc
    hint_source_bashrc
fi
