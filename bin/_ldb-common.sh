#!/usr/bin/env bash
#
# bin/_ldb-common.sh - Shared layout helpers for ldb_toolchain.
#
# Layout (multi-version):
#   ~/tools/ldb_toolchain/versions/<version>/bin/gcc   each installed version
#   ~/tools/ldb_toolchain/current  -> versions/<version>   the active version
#
# PATH (bashrc.d/00-path.sh) points at current/bin, so switching the symlink
# changes the active toolchain immediately, no shell reload required.

LDB_ROOT="${LDB_ROOT:-$HOME/tools/ldb_toolchain}"
LDB_VERSIONS_DIR="$LDB_ROOT/versions"
LDB_CURRENT_LINK="$LDB_ROOT/current"
LDB_REPO="${LDB_REPO:-amosbird/ldb_toolchain_gen}"
LDB_FALLBACK_VERSION="${LDB_FALLBACK_VERSION:-v0.28}"

ldb_version_dir() {
    printf '%s\n' "$LDB_VERSIONS_DIR/$1"
}

ldb_is_installed() {
    [[ -x "$(ldb_version_dir "$1")/bin/gcc" ]]
}

# Print installed versions, newest-name last (sorted).
ldb_installed_versions() {
    [[ -d "$LDB_VERSIONS_DIR" ]] || return 0
    local d
    for d in "$LDB_VERSIONS_DIR"/*/; do
        [[ -x "${d}bin/gcc" ]] || continue
        basename "$d"
    done | sort -V
}

ldb_current_version() {
    [[ -L "$LDB_CURRENT_LINK" ]] || return 1
    basename "$(readlink "$LDB_CURRENT_LINK")"
}

# Point current -> versions/<version> (atomic relink). Version must be installed.
ldb_set_current() {
    local version="$1"
    if ! ldb_is_installed "$version"; then
        echo "ldb_toolchain $version is not installed ($(ldb_version_dir "$version"))" >&2
        return 1
    fi
    mkdir -p "$LDB_ROOT"
    ln -sfn "$LDB_VERSIONS_DIR/$version" "$LDB_CURRENT_LINK"
}

# Resolve the latest release tag from GitHub; empty output + non-zero on failure.
ldb_latest_version() {
    local tag=""

    # Method 1: follow the /releases/latest redirect and read the final tag.
    # This avoids the GitHub API rate limit (which 403s on shared IPs).
    if command -v curl >/dev/null 2>&1; then
        local final
        final="$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
            "https://github.com/${LDB_REPO}/releases/latest" 2>/dev/null || true)"
        [[ "$final" == */releases/tag/* ]] && tag="${final##*/}"
    fi

    # Method 2: fall back to the GitHub API.
    if [[ -z "$tag" ]]; then
        local api="https://api.github.com/repos/${LDB_REPO}/releases/latest"
        if command -v curl >/dev/null 2>&1; then
            tag="$(curl -fsSL "$api" 2>/dev/null | grep -m1 '"tag_name":' \
                | sed -E 's/.*"tag_name":[[:space:]]*"([^"]+)".*/\1/')"
        elif command -v wget >/dev/null 2>&1; then
            tag="$(wget -qO- "$api" 2>/dev/null | grep -m1 '"tag_name":' \
                | sed -E 's/.*"tag_name":[[:space:]]*"([^"]+)".*/\1/')"
        fi
    fi

    [[ -n "$tag" ]] || return 1
    printf '%s\n' "$tag"
}
