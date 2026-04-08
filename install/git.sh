#!/usr/bin/env bash
# install/git.sh - Install git to ~/tools/git and deploy gitconfig

if [[ -z "${BASH_VERSION:-}" ]]; then
    exec bash "$0" "$@"
fi

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/code/dotfiles}"
TOOLS_DIR="$HOME/tools"
GIT_INSTALL_DIR="$TOOLS_DIR/git"
GIT_SOURCE_DIR="$TOOLS_DIR/git-src"
GIT_VERSION="${GIT_VERSION:-2.53.0}"
GIT_URL="${GIT_URL:-https://mirrors.edge.kernel.org/pub/software/scm/git/git-${GIT_VERSION}.tar.xz}"

info()    { printf "\033[34m[INFO]\033[0m %s\n" "$1"; }
warn()    { printf "\033[33m[WARN]\033[0m %s\n" "$1"; }
success() { printf "\033[32m[ OK ]\033[0m %s\n" "$1"; }

install_git() {
    echo
    info "=== Git Setup ==="
    echo

    if command -v git &>/dev/null; then
        success "Git is already installed: $(git --version)"
    else
        local tmp_file tmp_dir src_dir make_cmd
        read -rp "Install git to $GIT_INSTALL_DIR from source? [Y/n] " answer
        answer="${answer:-Y}"
        if [[ ! "$answer" =~ ^[Yy]$ ]]; then
            warn "Skipping git installation"
            return 0
        fi

        if ! command -v make &>/dev/null || ! command -v gcc &>/dev/null; then
            warn "Building git requires 'make' and 'gcc' in the current environment."
            warn "Please provide build tools in your user environment or set GIT_URL to a compatible prebuilt package."
            return 1
        fi

        tmp_file="/tmp/git-${GIT_VERSION}-$$.tar.xz"
        tmp_dir="$(mktemp -d)"
        mkdir -p "$TOOLS_DIR"

        info "Downloading git source..."
        info "URL: $GIT_URL"
        if command -v curl &>/dev/null; then
            curl -fSL "$GIT_URL" -o "$tmp_file" || {
                rm -rf "$tmp_dir"
                warn "Download failed."
                return 1
            }
        elif command -v wget &>/dev/null; then
            wget -q --show-progress "$GIT_URL" -O "$tmp_file" || {
                rm -rf "$tmp_dir"
                warn "Download failed."
                return 1
            }
        else
            rm -rf "$tmp_dir"
            warn "Neither curl nor wget found. Please install git manually."
            return 1
        fi

        tar -xJf "$tmp_file" -C "$tmp_dir"
        src_dir="$(printf '%s\n' "$tmp_dir"/* | sed -n '1p')"
        rm -rf "$GIT_SOURCE_DIR" "$GIT_INSTALL_DIR"
        mv "$src_dir" "$GIT_SOURCE_DIR"
        mkdir -p "$GIT_INSTALL_DIR"

        make_cmd="make prefix=$GIT_INSTALL_DIR NO_GETTEXT=YesPlease NO_TCLTK=YesPlease"
        if ! bash -lc "$make_cmd -j\$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)" >/dev/null; then
            warn "Git build failed. Missing user-space build dependencies are likely."
            warn "Needed at minimum: libc headers, zlib, openssl, curl, expat development libraries."
            rm -f "$tmp_file"
            rm -rf "$tmp_dir"
            return 1
        fi
        bash -lc "$make_cmd install" >/dev/null || {
            warn "Git install step failed."
            rm -f "$tmp_file"
            rm -rf "$tmp_dir"
            return 1
        }

        rm -f "$tmp_file"
        rm -rf "$tmp_dir"
        success "Git installed: $($GIT_INSTALL_DIR/bin/git --version)"
    fi
}

configure_git() {
    local gitconfig_src="$DOTFILES_DIR/gitconfig"
    local gitconfig_dst="$HOME/.gitconfig"

    if [[ ! -f "$gitconfig_src" ]]; then
        warn "gitconfig template not found at $gitconfig_src"
        return 1
    fi

    # Get user info interactively
    local current_name current_email
    current_name="$(git config --global user.name 2>/dev/null || echo '')"
    current_email="$(git config --global user.email 2>/dev/null || echo '')"

    read -rp "Git user name [${current_name:-your name}]: " git_name
    git_name="${git_name:-$current_name}"

    read -rp "Git user email [${current_email:-your email}]: " git_email
    git_email="${git_email:-$current_email}"

    if [[ -z "$git_name" || -z "$git_email" ]]; then
        warn "Name and email are required for git config"
        return 1
    fi

    # Backup existing gitconfig
    if [[ -f "$gitconfig_dst" ]]; then
        cp "$gitconfig_dst" "${gitconfig_dst}.bak.$(date +%Y%m%d%H%M%S)"
        info "Backed up existing .gitconfig"
    fi

    # Render template: replace placeholders
    sed -e "s|__GIT_NAME__|${git_name}|g" \
        -e "s|__GIT_EMAIL__|${git_email}|g" \
        "$gitconfig_src" > "$gitconfig_dst"

    success "Git configured: name=$git_name, email=$git_email"
    success "Written to $gitconfig_dst"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]:-$0}" == "$0" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
    source "$SCRIPT_DIR/_common.sh"

    install_git
    configure_git
    ensure_bashrc
    hint_source_bashrc
fi
