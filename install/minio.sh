#!/usr/bin/env bash
# install/minio.sh - Install a local MinIO server + mc client (official binaries)
#
# Downloads the standalone MinIO server and mc client binaries (no brew, no sudo,
# no system package manager), writes a machine-local config under
# ~/workspace/minio, and prepares the data directory.

if [[ -z "${BASH_VERSION:-}" ]]; then
    exec bash "$0" "$@"
fi

set -euo pipefail

if ! declare -f info &>/dev/null; then
    info()    { printf "\033[34m[INFO]\033[0m %s\n" "$1"; }
    warn()    { printf "\033[33m[WARN]\033[0m %s\n" "$1"; }
    success() { printf "\033[32m[ OK ]\033[0m %s\n" "$1"; }
fi

MINIO_TOOLS_DIR="${MINIO_TOOLS_DIR:-$HOME/tools/minio}"
MINIO_WORKSPACE_DIR="${MINIO_WORKSPACE_DIR:-$HOME/workspace/minio}"
MINIO_DOWNLOAD_DIR="${MINIO_DOWNLOAD_DIR:-$HOME/downloads/minio}"

MINIO_API_PORT="${MINIO_API_PORT:-19900}"
MINIO_CONSOLE_PORT="${MINIO_CONSOLE_PORT:-19901}"
MINIO_ROOT_USER="${MINIO_ROOT_USER:-minioadmin}"
MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:-minioadmin}"
MINIO_BUCKET="${MINIO_BUCKET:-clickhouse}"

_minio_detect_os() {
    case "$(uname -s)" in
        Linux) echo "linux" ;;
        Darwin) echo "darwin" ;;
        *)
            warn "Unsupported OS: $(uname -s)"
            return 1
            ;;
    esac
}

_minio_detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        *)
            warn "Unsupported architecture: $(uname -m)"
            return 1
            ;;
    esac
}

_minio_download_binary() {
    local url="$1"
    local target="$2"

    if [[ -x "$target" ]]; then
        success "Already installed: $target"
        return 0
    fi

    info "Downloading: $url"
    if ! curl -fSL --progress-bar -o "${target}.tmp" "$url"; then
        rm -f "${target}.tmp"
        warn "Failed to download: $url"
        return 1
    fi
    chmod +x "${target}.tmp"
    mv "${target}.tmp" "$target"
    success "Installed: $target"
}

_minio_write_conf_if_absent() {
    local conf_file="$MINIO_WORKSPACE_DIR/minio.conf"
    if [[ -f "$conf_file" ]]; then
        success "MinIO config exists: $conf_file"
        return 0
    fi

    cat > "$conf_file" <<EOF
# Local MinIO configuration
# Edit this file and restart: restart-minio
#
# Changing credentials/bucket here also requires re-running:
#   configure-ch-s3-minio all

api_port = ${MINIO_API_PORT}
console_port = ${MINIO_CONSOLE_PORT}
root_user = ${MINIO_ROOT_USER}
root_password = ${MINIO_ROOT_PASSWORD}
bucket = ${MINIO_BUCKET}
data_dir = ${MINIO_WORKSPACE_DIR}/data
EOF
    success "Initialized MinIO config: $conf_file"
}

install_minio() {
    local os arch base
    os="$(_minio_detect_os)" || return 0
    arch="$(_minio_detect_arch)" || return 0
    base="https://dl.min.io"

    mkdir -p "$MINIO_TOOLS_DIR" "$MINIO_WORKSPACE_DIR" "$MINIO_WORKSPACE_DIR/data" \
        "$MINIO_WORKSPACE_DIR/mc" "$MINIO_DOWNLOAD_DIR"

    _minio_download_binary \
        "${base}/server/minio/release/${os}-${arch}/minio" \
        "$MINIO_TOOLS_DIR/minio" || return 1

    _minio_download_binary \
        "${base}/client/mc/release/${os}-${arch}/mc" \
        "$MINIO_TOOLS_DIR/mc" || return 1

    _minio_write_conf_if_absent

    success "MinIO is ready under: $MINIO_TOOLS_DIR"
    info "Start it with:        start-minio"
    info "Then wire ClickHouse: configure-ch-s3-minio all"
}

if [[ "${BASH_SOURCE[0]:-$0}" == "$0" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
    source "$SCRIPT_DIR/_common.sh"

    install_minio
    ensure_bashrc
    hint_source_bashrc
fi
