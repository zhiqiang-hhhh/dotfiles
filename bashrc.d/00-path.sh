# bashrc.d/00-path.sh - PATH configuration
# Sourced by ~/.bashrc via dotfiles

# Dotfiles bin directory
[[ -d "$HOME/bin" ]] && export PATH="$HOME/bin:$PATH"
[[ -d "$HOME/code/dotfiles/bin" ]] && export PATH="$HOME/code/dotfiles/bin:$PATH"

# ldb_toolchain
[[ -d "$HOME/tools/ldb_toolchain/bin" ]] && export PATH="$HOME/tools/ldb_toolchain/bin:$PATH"

# anaconda (conda-standalone)
[[ -d "$HOME/tools/anaconda/bin" ]] && export PATH="$HOME/tools/anaconda/bin:$PATH"

# rclone
[[ -d "$HOME/tools/rclone/bin" ]] && export PATH="$HOME/tools/rclone/bin:$PATH"

# GitHub CLI
[[ -d "$HOME/tools/github-cli/bin" ]] && export PATH="$HOME/tools/github-cli/bin:$PATH"

# Maven
[[ -d "$HOME/tools/maven/bin" ]] && export PATH="$HOME/tools/maven/bin:$PATH"

# Go
[[ -d "$HOME/tools/go/bin" ]] && export PATH="$HOME/tools/go/bin:$PATH"
[[ -d "$HOME/go/bin" ]] && export PATH="$HOME/go/bin:$PATH"

# Java - prefer JAVA_HOME if set
if [[ -n "${JAVA_HOME:-}" && -d "$JAVA_HOME/bin" ]]; then
    export PATH="$JAVA_HOME/bin:$PATH"
fi

# Local bin (pip, etc.)
[[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"

# Deduplicate PATH entries while preserving order
_dedupe_path() {
    local IFS=':'
    local -a new_path=()
    local -A seen=()
    for dir in $PATH; do
        if [[ -z "${seen[$dir]:-}" ]]; then
            seen[$dir]=1
            new_path+=("$dir")
        fi
    done
    PATH="$(printf '%s:' "${new_path[@]}")"
    PATH="${PATH%:}"  # Remove trailing colon
    export PATH
}
_dedupe_path
unset -f _dedupe_path
