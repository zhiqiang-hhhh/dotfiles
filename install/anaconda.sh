#!/usr/bin/env bash
# install/anaconda.sh - Install conda package manager (binary-only)

if [[ -z "${BASH_VERSION:-}" ]]; then
    exec bash "$0" "$@"
fi

set -euo pipefail

CONDA_STANDALONE_VERSION="${CONDA_STANDALONE_VERSION:-latest}"
TOOLS_DIR="$HOME/tools"
ANACONDA_INSTALL_DIR="$TOOLS_DIR/anaconda"
ANACONDA_BIN_DIR="$ANACONDA_INSTALL_DIR/bin"
ANACONDA_URL="${ANACONDA_URL:-}"
ANACONDA_API_URL="https://api.anaconda.org/package/conda-forge/conda-standalone"

info()    { printf "\033[34m[INFO]\033[0m %s\n" "$1"; }
warn()    { printf "\033[33m[WARN]\033[0m %s\n" "$1"; }
success() { printf "\033[32m[ OK ]\033[0m %s\n" "$1"; }

_configure_conda_bash_hook() {
    local bashrc="$HOME/.bashrc"
    local marker_begin="# >>> conda initialize >>>"
    local marker_end="# <<< conda initialize <<<"
    local tmp_file
    tmp_file="$(mktemp)"

    if [[ -f "$bashrc" ]]; then
        awk -v begin="$marker_begin" -v end="$marker_end" '
            $0 == begin {in_block=1; next}
            $0 == end {in_block=0; next}
            in_block != 1 {print}
        ' "$bashrc" > "$tmp_file"
    fi

    cat >> "$tmp_file" <<'BASHRC_BLOCK'

# >>> conda initialize >>>
# !! Managed by dotfiles install/anaconda.sh !!
export CONDA_ROOT_PREFIX="$HOME/tools/anaconda"
__conda_setup="$("$HOME/tools/anaconda/bin/conda" 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    export PATH="$HOME/tools/anaconda/bin:$PATH"
fi
unset __conda_setup
# <<< conda initialize <<<
BASHRC_BLOCK

    mv "$tmp_file" "$bashrc"
    success "Configured stable conda hook in $bashrc"
}

_extract_zst_tar() {
    local archive="$1"
    local dst="$2"

    if tar --help 2>/dev/null | grep -q -- '--zstd'; then
        tar --zstd -xf "$archive" -C "$dst"
        return 0
    fi

    if command -v zstd &>/dev/null; then
        zstd -dc "$archive" | tar -xf - -C "$dst"
        return 0
    fi

    warn "Cannot extract .tar.zst: neither 'tar --zstd' nor 'zstd' is available."
    warn "Please install zstd first (e.g., brew install zstd or sudo yum install -y zstd)."
    return 1
}

_extract_conda_package() {
    local pkg_file="$1"
    local dst="$2"
    local unpack_dir
    unpack_dir="$(mktemp -d)"

    if ! command -v unzip &>/dev/null; then
        warn "Cannot extract .conda package: 'unzip' is required."
        warn "Please install unzip first (e.g., brew install unzip or sudo yum install -y unzip)."
        rm -rf "$unpack_dir"
        return 1
    fi

    unzip -oq "$pkg_file" -d "$unpack_dir"

    local pkg_archive=""
    local info_archive=""
    local f
    for f in "$unpack_dir"/pkg-*.tar.zst; do
        [[ -f "$f" ]] && pkg_archive="$f" && break
    done
    for f in "$unpack_dir"/info-*.tar.zst; do
        [[ -f "$f" ]] && info_archive="$f" && break
    done

    if [[ -z "$pkg_archive" || -z "$info_archive" ]]; then
        warn "Unexpected .conda package format: missing pkg/info payload archives."
        rm -rf "$unpack_dir"
        return 1
    fi

    _extract_zst_tar "$pkg_archive" "$dst" || {
        rm -rf "$unpack_dir"
        return 1
    }
    _extract_zst_tar "$info_archive" "$dst" || {
        rm -rf "$unpack_dir"
        return 1
    }

    rm -rf "$unpack_dir"
}

_detect_subdir() {
    local os
    local arch
    os="$(uname -s)"
    arch="$(uname -m)"
    case "$os" in
        Linux)
            case "$arch" in
                x86_64|amd64)
                    echo "linux-64"
                    ;;
                aarch64|arm64)
                    echo "linux-aarch64"
                    ;;
                *)
                    warn "Unsupported architecture: $arch"
                    return 1
                    ;;
            esac
            ;;
        Darwin)
            case "$arch" in
                x86_64|amd64)
                    echo "osx-64"
                    ;;
                aarch64|arm64)
                    echo "osx-arm64"
                    ;;
                *)
                    warn "Unsupported architecture: $arch"
                    return 1
                    ;;
            esac
            ;;
        *)
            warn "Unsupported OS: $os"
            return 1
            ;;
    esac
}

_resolve_download_url() {
    local target_version="$1"
    local subdir="$2"
    local api_url="$3"

    python3 - "$target_version" "$subdir" "$api_url" <<'PY'
import json
import sys
import urllib.request

target_version = sys.argv[1]
subdir = sys.argv[2]
api_url = sys.argv[3]

with urllib.request.urlopen(api_url) as resp:
    data = json.load(resp)

if target_version == "latest":
    target_version = data.get("latest_version", "")

if not target_version:
    print("", end="")
    raise SystemExit(1)

files = data.get("files", [])

preferred = None
fallback = None
prefix = f"{subdir}/conda-standalone-{target_version}-"

for f in files:
    basename = f.get("basename", "")
    if not basename.startswith(prefix):
        continue
    if basename.endswith(".tar.bz2"):
        preferred = f
        break
    if basename.endswith(".conda"):
        fallback = f

chosen = preferred or fallback
if not chosen:
    print("", end="")
    raise SystemExit(1)

download_url = chosen.get("download_url", "")
if download_url.startswith("//"):
    download_url = "https:" + download_url

print(download_url)
PY
}

install_anaconda() {
    echo
    info "=== Anaconda (conda-standalone) Setup (${CONDA_STANDALONE_VERSION}) ==="
    echo

    if [[ -x "$ANACONDA_BIN_DIR/conda" ]]; then
        success "conda already installed at $ANACONDA_BIN_DIR/conda"
        "$ANACONDA_BIN_DIR/conda" --version || true
        read -rp "Reinstall conda? [y/N] " answer
        answer="${answer:-N}"
        if [[ ! "$answer" =~ ^[Yy]$ ]]; then
            _configure_conda_bash_hook
            return 0
        fi
    else
        read -rp "Install conda to $ANACONDA_INSTALL_DIR? [Y/n] " answer
        answer="${answer:-Y}"
        if [[ ! "$answer" =~ ^[Yy]$ ]]; then
            warn "Skipping conda installation"
            return 0
        fi
    fi

    local subdir
    subdir="$(_detect_subdir)" || return 1

    if [[ -z "$ANACONDA_URL" ]]; then
        info "Resolving conda-standalone download URL..."
        if ! ANACONDA_URL="$(_resolve_download_url "$CONDA_STANDALONE_VERSION" "$subdir" "$ANACONDA_API_URL")"; then
            warn "Failed to resolve download URL from conda-forge metadata."
            warn "Set ANACONDA_URL manually and rerun this script."
            return 1
        fi
    fi

    local tmp_file
    tmp_file="/tmp/conda-standalone-${subdir}-$$"

    info "Downloading conda package..."
    info "URL: $ANACONDA_URL"
    if command -v curl &>/dev/null; then
        if ! curl -fSL "$ANACONDA_URL" -o "$tmp_file"; then
            warn "Download failed."
            return 1
        fi
    elif command -v wget &>/dev/null; then
        if ! wget -q --show-progress "$ANACONDA_URL" -O "$tmp_file"; then
            warn "Download failed."
            return 1
        fi
    else
        warn "Neither curl nor wget found. Please install conda manually."
        return 1
    fi

    rm -rf "$ANACONDA_INSTALL_DIR"
    mkdir -p "$ANACONDA_INSTALL_DIR"

    case "$ANACONDA_URL" in
        *.tar.bz2)
            tar -xjf "$tmp_file" -C "$ANACONDA_INSTALL_DIR"
            ;;
        *.conda)
            info "Extracting .conda package..."
            if ! _extract_conda_package "$tmp_file" "$ANACONDA_INSTALL_DIR"; then
                rm -f "$tmp_file"
                return 1
            fi
            ;;
        *)
            warn "Unexpected package format: $ANACONDA_URL"
            rm -f "$tmp_file"
            return 1
            ;;
    esac

    rm -f "$tmp_file"

    # Some conda-standalone builds ship as standalone_conda/conda.exe.
    # Normalize to ~/tools/anaconda/bin/conda so PATH setup remains stable.
    if [[ ! -x "$ANACONDA_BIN_DIR/conda" ]]; then
        mkdir -p "$ANACONDA_BIN_DIR"
        if [[ -f "$ANACONDA_INSTALL_DIR/standalone_conda/conda.exe" ]]; then
            install -m 755 "$ANACONDA_INSTALL_DIR/standalone_conda/conda.exe" "$ANACONDA_BIN_DIR/conda"
        elif [[ -f "$ANACONDA_INSTALL_DIR/standalone_conda/conda" ]]; then
            install -m 755 "$ANACONDA_INSTALL_DIR/standalone_conda/conda" "$ANACONDA_BIN_DIR/conda"
        elif [[ -f "$ANACONDA_INSTALL_DIR/conda" ]]; then
            install -m 755 "$ANACONDA_INSTALL_DIR/conda" "$ANACONDA_BIN_DIR/conda"
        fi
    fi

    if [[ -x "$ANACONDA_BIN_DIR/conda" ]]; then
        success "conda installed: $ANACONDA_BIN_DIR/conda"
        "$ANACONDA_BIN_DIR/conda" --version || true
        _configure_conda_bash_hook
    else
        warn "conda installation may have failed, binary not found"
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]:-$0}" == "$0" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
    source "$SCRIPT_DIR/_common.sh"

    install_anaconda
    ensure_bashrc
    hint_source_bashrc
fi
