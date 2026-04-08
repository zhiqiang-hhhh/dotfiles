# bashrc.d/45-monitoring.sh - Monitoring stack helper functions

if ! declare -f _run_dotfiles_bin &>/dev/null; then
    _dotfiles_bin() {
        printf '%s\n' "$HOME/code/dotfiles/bin"
    }

    _run_dotfiles_bin() {
        local cmd_name="$1"
        shift

        local cmd_path
        cmd_path="$(_dotfiles_bin)/$cmd_name"

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
fi

cmonitoring() {
    cd "$HOME/workspace/monitoring" || return
}

monitoring_start() {
    _run_dotfiles_bin monitoring-start "$@"
}

monitoring_stop() {
    _run_dotfiles_bin monitoring-stop "$@"
}

monitoring_status() {
    _run_dotfiles_bin monitoring-status "$@"
}

monitoring_add_doris() {
    _run_dotfiles_bin monitoring-add-doris "$@"
}
