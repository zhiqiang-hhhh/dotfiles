#!/usr/bin/env bash
#
# install/doris-workspace.sh - Prepare Doris runtime workspace layout
#
# Keeps machine-local configs under ~/workspace while linking key runtime
# binaries/directories to ~/code/doris/output so rebuilt artifacts are picked
# up after restart.
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

    if [[ -L "$link_path" ]]; then
        if [[ "$(readlink -f "$link_path")" == "$(readlink -f "$target_path")" ]]; then
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

_copy_dir_if_absent() {
    local src_dir="$1"
    local dst_dir="$2"

    if [[ -d "$src_dir" && ! -e "$dst_dir" ]]; then
        cp -a "$src_dir" "$dst_dir"
        success "Initialized: $dst_dir"
    fi
}

_upsert_conf_key() {
    local conf_file="$1"
    local key="$2"
    local value="$3"

    if grep -qE "^[[:space:]]*${key}[[:space:]]*=" "$conf_file"; then
        sed -i -E "s|^[[:space:]]*${key}[[:space:]]*=.*|${key} = ${value}|" "$conf_file"
    else
        printf "\n%s = %s\n" "$key" "$value" >> "$conf_file"
    fi
}

install_doris_workspace() {
    local doris_dir="$HOME/code/doris"
    local output_fe_dir="$doris_dir/output/fe"
    local output_be_dir="$doris_dir/output/be"
    local workspace_doris_dir="$HOME/workspace/doris"
    local workspace_fe_dir="$workspace_doris_dir/fe"
    local workspace_be_dir="$workspace_doris_dir/be"
    local workspace_fe_meta_dir="$workspace_fe_dir/doris-meta"
    local workspace_be_storage_dir="$workspace_be_dir/storage"
    local workspace_be_tmp_dir="$workspace_be_storage_dir/tmp"

    if [[ ! -d "$doris_dir" ]]; then
        warn "Doris source tree not found: $doris_dir"
        warn "Clone it first, then run this script again."
        return 0
    fi
    if [[ ! -d "$output_fe_dir" || ! -d "$output_be_dir" ]]; then
        warn "Doris output directories not found under $doris_dir/output"
        warn "Build Doris first to generate output/fe and output/be."
        return 0
    fi
    if [[ ! -d "$output_fe_dir/lib" ]]; then
        warn "Missing FE lib directory: $output_fe_dir/lib"
        return 0
    fi
    if [[ ! -d "$output_fe_dir/bin" ]]; then
        warn "Missing FE bin directory: $output_fe_dir/bin"
        return 0
    fi
    if [[ ! -d "$output_be_dir/bin" ]]; then
        warn "Missing BE bin directory: $output_be_dir/bin"
        return 0
    fi
    if [[ ! -d "$output_be_dir/lib" ]]; then
        warn "Missing BE lib directory: $output_be_dir/lib"
        return 0
    fi

    mkdir -p "$workspace_fe_dir" "$workspace_be_dir" "$workspace_be_dir/lib"

    _copy_dir_if_absent "$output_fe_dir/conf" "$workspace_fe_dir/conf"
    _copy_dir_if_absent "$output_be_dir/conf" "$workspace_be_dir/conf"
    _copy_dir_if_absent "$output_fe_dir/doris-meta" "$workspace_fe_meta_dir"

    mkdir -p "$workspace_fe_meta_dir"

    _ensure_symlink "$workspace_fe_dir/bin" "$output_fe_dir/bin"
    _ensure_symlink "$workspace_fe_dir/lib" "$output_fe_dir/lib"
    _ensure_symlink "$workspace_be_dir/bin" "$output_be_dir/bin"
    _ensure_symlink "$workspace_be_dir/lib" "$output_be_dir/lib"

    mkdir -p "$workspace_be_storage_dir" "$workspace_be_tmp_dir"

    local be_conf="$workspace_be_dir/conf/be.conf"
    if [[ ! -f "$be_conf" ]]; then
        warn "BE config not found at $be_conf"
        warn "Expected it from $output_be_dir/conf/be.conf"
        return 0
    fi

    _upsert_conf_key "$be_conf" "storage_root_path" "${workspace_be_storage_dir}"
    _upsert_conf_key "$be_conf" "tmp_file_dirs" "${workspace_be_tmp_dir}"
    success "Updated BE config: $be_conf"

    info "Workspace Doris runtime is ready at: $workspace_doris_dir"
}

if [[ "${BASH_SOURCE[0]:-$0}" == "$0" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
    source "$SCRIPT_DIR/_common.sh"

    install_doris_workspace
    ensure_bashrc
    hint_source_bashrc
fi
