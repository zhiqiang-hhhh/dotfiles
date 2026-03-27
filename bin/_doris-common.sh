#!/usr/bin/env bash

doris_fe_conf_path() {
    printf '%s\n' "$HOME/workspace/doris/fe/conf/fe.conf"
}

doris_be_conf_path() {
    printf '%s\n' "$HOME/workspace/doris/be/conf/be.conf"
}

doris_conf_get() {
    local conf_file="$1"
    local key="$2"
    local default_value="${3:-}"
    local line

    if [[ ! -f "$conf_file" ]]; then
        printf '%s\n' "$default_value"
        return 0
    fi

    line="$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "$conf_file" | tail -n1 || true)"
    if [[ -z "$line" ]]; then
        printf '%s\n' "$default_value"
        return 0
    fi

    line="${line#*=}"
    line="${line%%#*}"
    line="$(printf '%s' "$line" | xargs)"
    printf '%s\n' "$line"
}

doris_component_home() {
    local component="$1"
    case "$component" in
        fe)
            printf '%s\n' "$HOME/workspace/doris/fe"
            ;;
        be)
            printf '%s\n' "$HOME/workspace/doris/be"
            ;;
        *)
            echo "unsupported component: $component" >&2
            return 1
            ;;
    esac
}

doris_restart_component() {
    local component="$1"
    shift

    local home_dir
    local bin_dir
    local start_script
    local stop_script

    home_dir="$(doris_component_home "$component")"
    bin_dir="$home_dir/bin"
    start_script="$bin_dir/start_${component}.sh"
    stop_script="$bin_dir/stop_${component}.sh"

    if [[ ! -x "$start_script" ]]; then
        echo "missing executable: $start_script" >&2
        return 1
    fi
    if [[ ! -x "$stop_script" ]]; then
        echo "missing executable: $stop_script" >&2
        return 1
    fi

    echo "Restarting Doris ${component^^} at: $home_dir"
    if ! "$stop_script"; then
        echo "WARN: stop_${component}.sh returned non-zero, continuing start" >&2
    fi

    if [[ "$#" -eq 0 ]]; then
        echo "Starting Doris ${component^^} in daemon mode"
        "$start_script" --daemon
    else
        "$start_script" "$@"
    fi
}
