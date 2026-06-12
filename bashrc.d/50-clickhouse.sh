# bashrc.d/50-clickhouse.sh - ClickHouse runtime helper functions

_dotfiles_bin_clickhouse() {
    printf '%s\n' "$HOME/code/dotfiles/bin"
}

_run_dotfiles_clickhouse_bin() {
    local cmd_name="$1"
    shift

    local cmd_path
    cmd_path="$(_dotfiles_bin_clickhouse)/$cmd_name"

    if [[ -x "$cmd_path" ]]; then
        "$cmd_path" "$@"
    elif command -v "$cmd_name" &>/dev/null; then
        "$cmd_name" "$@"
    else
        echo "$cmd_name: command not found"
        echo "expected executable: $cmd_path"
        return 1
    fi
}

cch() {
    cd "$HOME/workspace/clickhouse" || return
}

czk() {
    cd "$HOME/workspace/zookeeper" || return
}

deploy_ch() {
    _run_dotfiles_clickhouse_bin deploy-ch "$@"
}

start_ch() {
    _run_dotfiles_clickhouse_bin start-ch "$@"
}

stop_ch() {
    _run_dotfiles_clickhouse_bin stop-ch "$@"
}

restart_ch() {
    _run_dotfiles_clickhouse_bin restart-ch "$@"
}

status_ch() {
    _run_dotfiles_clickhouse_bin status-ch "$@"
}

start_zk() {
    _run_dotfiles_clickhouse_bin start-zk "$@"
}

stop_zk() {
    _run_dotfiles_clickhouse_bin stop-zk "$@"
}

restart_zk() {
    _run_dotfiles_clickhouse_bin restart-zk "$@"
}

status_zk() {
    _run_dotfiles_clickhouse_bin status-zk "$@"
}

client_ch() {
    _run_dotfiles_clickhouse_bin client-ch "$@"
}

help_ch() {
    _run_dotfiles_clickhouse_bin help-ch "$@"
}
