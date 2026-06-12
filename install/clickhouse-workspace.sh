#!/usr/bin/env bash
#
# install/clickhouse-workspace.sh - Prepare local ClickHouse workspace layout
#
# Keeps machine-local ClickHouse configs and data under ~/workspace/clickhouse,
# while linking the runtime binary to a built ClickHouse tree under ~/code.
#

if [[ -z "${BASH_VERSION:-}" ]]; then
    exec bash "$0" "$@"
fi

set -euo pipefail

if ! declare -f info &>/dev/null; then
    info()    { printf "\033[34m[INFO]\033[0m %s\n" "$1"; }
    warn()    { printf "\033[33m[WARN]\033[0m %s\n" "$1"; }
    success() { printf "\033[32m[ OK ]\033[0m %s\n" "$1"; }
fi

_clickhouse_workspace() {
    printf '%s\n' "${CLICKHOUSE_WORKSPACE:-$HOME/workspace/clickhouse}"
}

_clickhouse_find_built_binary() {
    if [[ -n "${CLICKHOUSE_BINARY:-}" ]]; then
        printf '%s\n' "$CLICKHOUSE_BINARY"
        return 0
    fi

    local build_dir="${CLICKHOUSE_BUILD_DIR:-$HOME/code/ClickHouse/build}"
    if [[ -x "$build_dir/programs/clickhouse" ]]; then
        printf '%s\n' "$build_dir/programs/clickhouse"
        return 0
    fi

    if [[ -x "$HOME/code/ClickHouse/build-debug/programs/clickhouse" ]]; then
        printf '%s\n' "$HOME/code/ClickHouse/build-debug/programs/clickhouse"
        return 0
    fi

    printf '%s\n' "$build_dir/programs/clickhouse"
}

_backup_path_if_exists() {
    local path="$1"

    if [[ -e "$path" || -L "$path" ]]; then
        local backup_path="${path}.bak.$(date +%Y%m%d%H%M%S)"
        mv "$path" "$backup_path"
        warn "Backed up: $path -> $backup_path"
    fi
}

_ensure_symlink() {
    local link_path="$1"
    local target_path="$2"
    local current_target

    if [[ -L "$link_path" ]]; then
        current_target="$(readlink "$link_path")"
        if [[ "$current_target" == "$target_path" ]]; then
            success "Symlink exists: $link_path -> $target_path"
            return 0
        fi
        rm -f "$link_path"
    elif [[ -e "$link_path" ]]; then
        _backup_path_if_exists "$link_path"
    fi

    ln -s "$target_path" "$link_path"
    success "Symlink created: $link_path -> $target_path"
}

install_clickhouse_workspace() {
    local workspace_dir
    local binary_path
    local zk_home

    workspace_dir="$(_clickhouse_workspace)"
    binary_path="$(_clickhouse_find_built_binary)"
    zk_home="${ZOOKEEPER_HOME:-$HOME/workspace/zookeeper/apache-zookeeper-3.8.6-bin}"

    if [[ ! -x "$binary_path" ]]; then
        warn "ClickHouse binary not found or not executable: $binary_path"
        warn "Build ClickHouse first, or set CLICKHOUSE_BINARY=/path/to/clickhouse"
        return 0
    fi

    mkdir -p \
        "$workspace_dir/bin" \
        "$workspace_dir/conf" \
        "$workspace_dir/logs/node1" \
        "$workspace_dir/logs/node2" \
        "$workspace_dir/run" \
        "$workspace_dir/storage/node1/data" \
        "$workspace_dir/storage/node1/tmp" \
        "$workspace_dir/storage/node1/access" \
        "$workspace_dir/storage/node1/user_files" \
        "$workspace_dir/storage/node1/format_schemas" \
        "$workspace_dir/storage/node2/data" \
        "$workspace_dir/storage/node2/tmp" \
        "$workspace_dir/storage/node2/access" \
        "$workspace_dir/storage/node2/user_files" \
        "$workspace_dir/storage/node2/format_schemas" \
        "$workspace_dir/storage/data" \
        "$workspace_dir/storage/tmp" \
        "$workspace_dir/storage/access" \
        "$workspace_dir/storage/user_files" \
        "$workspace_dir/storage/format_schemas"

    _ensure_symlink "$workspace_dir/bin/clickhouse" "$binary_path"

    local required_configs=(
        "$workspace_dir/conf/users.xml"
        "$workspace_dir/conf/config.xml"
        "$workspace_dir/conf/node1.xml"
        "$workspace_dir/conf/node2.xml"
    )
    local conf
    for conf in "${required_configs[@]}"; do
        if [[ -f "$conf" ]]; then
            success "Config exists: $conf"
        else
            warn "Missing config: $conf"
        fi
    done

    if [[ -x "$zk_home/bin/zkServer.sh" && -f "$zk_home/conf/zoo.cfg" ]]; then
        success "ZooKeeper detected: $zk_home"
    else
        warn "ZooKeeper not detected at: $zk_home"
        warn "Set ZOOKEEPER_HOME or install ZooKeeper under ~/workspace/zookeeper"
    fi

    success "ClickHouse workspace is ready at: $workspace_dir"
}

if [[ "${BASH_SOURCE[0]:-$0}" == "$0" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
    source "$SCRIPT_DIR/_common.sh"

    install_clickhouse_workspace "$@"
    ensure_bashrc
    hint_source_bashrc
fi
