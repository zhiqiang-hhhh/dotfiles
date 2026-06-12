# bashrc.d/46-minio.sh - Local MinIO helper functions

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

cminio() {
    cd "$HOME/workspace/minio" || return
}

deploy_minio() {
    _run_dotfiles_bin deploy-minio "$@"
}

start_minio() {
    _run_dotfiles_bin start-minio "$@"
}

stop_minio() {
    _run_dotfiles_bin stop-minio "$@"
}

restart_minio() {
    _run_dotfiles_bin restart-minio "$@"
}

status_minio() {
    _run_dotfiles_bin status-minio "$@"
}
