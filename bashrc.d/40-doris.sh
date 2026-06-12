# bashrc.d/40-doris.sh - Doris runtime helper functions

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

cdoris() {
    cd "$HOME/workspace/doris" || return
}

cfe() {
    cd "$HOME/workspace/doris/fe" || return
}

cbe() {
    cd "$HOME/workspace/doris/be" || return
}

tobe() {
    cd "$HOME/workspace/doris/be" || return
}

ports_doris() {
    _run_dotfiles_bin ports-doris "$@"
}

client_doris() {
    _run_dotfiles_bin client-doris "$@"
}

add_be() {
    _run_dotfiles_bin add-be "$@"
}

help_doris() {
    _run_dotfiles_bin help-doris "$@"
}

restart_fe() {
    _run_dotfiles_bin restart-fe "$@"
}

restart_be() {
    _run_dotfiles_bin restart-be "$@"
}

rebuild_doris() {
    _run_dotfiles_bin rebuild-doris "$@"
}
