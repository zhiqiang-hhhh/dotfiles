# bashrc.d/30-functions.sh - Utility functions with tab completion

# --- Quick directory navigation ---

# c <dir> - jump to ~/code/<dir>
c() {
    local dir="${1:-}"
    if [[ -z "$dir" ]]; then
        cd "$HOME/code" || return
    else
        cd "$HOME/code/$dir" || return
    fi
}

# w <dir> - jump to ~/workspace/<dir>
w() {
    local dir="${1:-}"
    if [[ -z "$dir" ]]; then
        cd "$HOME/workspace" || return
    else
        cd "$HOME/workspace/$dir" || return
    fi
}

# t <dir> - jump to ~/tools/<dir>
t() {
    local dir="${1:-}"
    if [[ -z "$dir" ]]; then
        cd "$HOME/tools" || return
    else
        cd "$HOME/tools/$dir" || return
    fi
}

# --- Tab completion for c/w/t ---

_complete_c() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local code_dir="$HOME/code"
    if [[ -d "$code_dir" ]]; then
        COMPREPLY=( $(cd "$code_dir" && compgen -d -- "$cur") )
    fi
}

_complete_w() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local ws_dir="$HOME/workspace"
    if [[ -d "$ws_dir" ]]; then
        COMPREPLY=( $(cd "$ws_dir" && compgen -d -- "$cur") )
    fi
}

_complete_t() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local tools_dir="$HOME/tools"
    if [[ -d "$tools_dir" ]]; then
        COMPREPLY=( $(cd "$tools_dir" && compgen -d -- "$cur") )
    fi
}

if command -v complete >/dev/null 2>&1; then
    complete -o nospace -F _complete_c c
    complete -o nospace -F _complete_w w
    complete -o nospace -F _complete_t t
fi

# --- Utility functions ---

# mkcd <dir> - create directory and cd into it
mkcd() {
    mkdir -p "$1" && cd "$1" || return
}

# extract <file> - extract common archive formats
extract() {
    if [[ ! -f "$1" ]]; then
        echo "extract: '$1' is not a valid file" >&2
        return 1
    fi
    case "$1" in
        *.tar.bz2) tar xjf "$1"   ;;
        *.tar.gz)  tar xzf "$1"   ;;
        *.tar.xz)  tar xJf "$1"   ;;
        *.bz2)     bunzip2 "$1"   ;;
        *.gz)      gunzip "$1"    ;;
        *.tar)     tar xf "$1"    ;;
        *.tbz2)    tar xjf "$1"   ;;
        *.tgz)     tar xzf "$1"   ;;
        *.zip)     unzip "$1"     ;;
        *.Z)       uncompress "$1";;
        *.7z)      7z x "$1"     ;;
        *.rar)     unrar x "$1"  ;;
        *)         echo "extract: unknown format '$1'" >&2; return 1 ;;
    esac
}

# serve [port] - start a simple HTTP server in current directory
serve() {
    local port="${1:-8000}"
    if command -v python3 &>/dev/null; then
        python3 -m http.server "$port"
    elif command -v python &>/dev/null; then
        python -m SimpleHTTPServer "$port"
    else
        echo "serve: python not found" >&2
        return 1
    fi
}
