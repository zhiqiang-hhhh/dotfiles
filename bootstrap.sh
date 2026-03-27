#!/usr/bin/env bash
#
# bootstrap.sh - One-command development machine setup
#
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/zhiqiang-hhhh/dotfiles/main/bootstrap.sh)
#
# What it does:
#   1. Creates standard directory structure (~/code, ~/workspace, ~/tools, ~/bin)
#   2. Installs git (if missing)
#   3. Generates SSH key and guides you to add it to GitHub
#   4. Clones this dotfiles repo to ~/code/dotfiles
#   5. Configures git (name, email)
#   6. Sets up bash (source-based, non-destructive)
#   7. Installs development tools (JDK 17, Maven, ldb_toolchain)
#   8. Clones your repos from repos.conf
#   9. Installs Doris thirdparty prebuilt dependencies
#  10. Prepares Doris workspace runtime layout
#

set -euo pipefail

# ============================================================
# Configuration
# ============================================================

GITHUB_USER="zhiqiang-hhhh"
DOTFILES_REPO="git@github.com:${GITHUB_USER}/dotfiles.git"
DOTFILES_REPO_HTTPS="https://github.com/${GITHUB_USER}/dotfiles.git"
DOTFILES_DIR="$HOME/code/dotfiles"

# ============================================================
# Helper functions
# ============================================================

info()    { printf "\033[34m[INFO]\033[0m %s\n" "$1"; }
warn()    { printf "\033[33m[WARN]\033[0m %s\n" "$1"; }
success() { printf "\033[32m[ OK ]\033[0m %s\n" "$1"; }
error()   { printf "\033[31m[ERR ]\033[0m %s\n" "$1"; }
header()  { printf "\n\033[1;35m========== %s ==========\033[0m\n\n" "$1"; }

confirm() {
    local prompt="${1:-Continue?}"
    local default="${2:-Y}"
    local answer
    read -rp "$prompt [${default}] " answer
    answer="${answer:-$default}"
    [[ "$answer" =~ ^[Yy]$ ]]
}

# ============================================================
# Step 1: Create directory structure
# ============================================================

setup_directories() {
    header "Step 1: Directory Structure"

    local dirs=("$HOME/code" "$HOME/workspace" "$HOME/tools" "$HOME/bin" "$HOME/downloads")
    for dir in "${dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            success "Directory exists: $dir"
        else
            mkdir -p "$dir"
            success "Created: $dir"
        fi
    done
}

# ============================================================
# Step 2: Install git
# ============================================================

setup_git_install() {
    header "Step 2: Git Installation"

    if command -v git &>/dev/null; then
        success "Git is already installed: $(git --version)"
        return 0
    fi

    info "Git not found, installing..."
    if command -v yum &>/dev/null; then
        sudo yum install -y git
    elif command -v apt-get &>/dev/null; then
        sudo apt-get update && sudo apt-get install -y git
    else
        error "Could not detect package manager. Please install git manually and re-run."
        exit 1
    fi
    success "Git installed: $(git --version)"
}

# ============================================================
# Step 3: SSH key setup
# ============================================================

setup_ssh() {
    header "Step 3: SSH Key Setup"

    local ssh_key="$HOME/.ssh/id_ed25519"

    if [[ -f "$ssh_key" ]]; then
        success "SSH key already exists: $ssh_key"
        info "Public key:"
        echo
        echo "  $(cat "${ssh_key}.pub")"
        echo
        return 0
    fi

    if ! confirm "Generate a new ed25519 SSH key?"; then
        warn "Skipping SSH key generation"
        return 0
    fi

    read -rp "Enter email for SSH key: " ssh_email
    if [[ -z "$ssh_email" ]]; then
        warn "No email provided, skipping SSH key generation"
        return 0
    fi

    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    ssh-keygen -t ed25519 -C "$ssh_email" -f "$ssh_key"

    # Start ssh-agent
    eval "$(ssh-agent -s)" >/dev/null 2>&1 || true
    ssh-add "$ssh_key" 2>/dev/null || true

    success "SSH key generated!"
    echo
    info "============================================"
    info "Your public key (copy and add to GitHub):"
    info "============================================"
    echo
    echo "  $(cat "${ssh_key}.pub")"
    echo
    info "Open: https://github.com/settings/keys"
    info "Click 'New SSH key', paste the key above, and save."
    echo
    read -rp "Press Enter after you've added the key to GitHub... " _
    echo

    # Test connection
    info "Testing GitHub SSH connection..."
    if ssh -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        success "GitHub SSH authentication verified!"
    else
        warn "Could not verify SSH connection (this may be normal)."
        warn "You can test later: ssh -T git@github.com"
    fi
}

# ============================================================
# Step 4: Clone dotfiles
# ============================================================

setup_clone_dotfiles() {
    header "Step 4: Clone Dotfiles"

    if [[ -d "$DOTFILES_DIR/.git" ]]; then
        success "Dotfiles already cloned at $DOTFILES_DIR"
        info "Pulling latest changes..."
        git -C "$DOTFILES_DIR" pull --ff-only 2>/dev/null || warn "Could not pull (maybe you have local changes)"
        return 0
    fi

    info "Cloning dotfiles to $DOTFILES_DIR..."

    # Try SSH first, fall back to HTTPS
    if git clone "$DOTFILES_REPO" "$DOTFILES_DIR" 2>/dev/null; then
        success "Cloned via SSH: $DOTFILES_REPO"
    elif git clone "$DOTFILES_REPO_HTTPS" "$DOTFILES_DIR" 2>/dev/null; then
        success "Cloned via HTTPS: $DOTFILES_REPO_HTTPS"
        warn "Using HTTPS (you may want to switch to SSH later)"
        warn "  cd $DOTFILES_DIR && git remote set-url origin $DOTFILES_REPO"
    else
        error "Failed to clone dotfiles repo!"
        error "Make sure the repo exists: https://github.com/${GITHUB_USER}/dotfiles"
        exit 1
    fi
}

# ============================================================
# Step 5: Configure git
# ============================================================

setup_git_config() {
    header "Step 5: Git Configuration"

    local gitconfig_src="$DOTFILES_DIR/gitconfig"
    local gitconfig_dst="$HOME/.gitconfig"
    local gitignore_dst="$HOME/.gitignore_global"

    if [[ ! -f "$gitconfig_src" ]]; then
        warn "gitconfig template not found, skipping"
        return 0
    fi

    # Check if gitconfig is already deployed by us (idempotent)
    if [[ -f "$gitconfig_dst" ]]; then
        local current_name current_email
        current_name="$(git config --global user.name 2>/dev/null || echo '')"
        current_email="$(git config --global user.email 2>/dev/null || echo '')"

        if [[ -n "$current_name" && -n "$current_email" ]]; then
            # Check if current config was rendered from our template
            if grep -qF "[format]" "$gitconfig_dst" 2>/dev/null && grep -qF "$current_name" "$gitconfig_dst" 2>/dev/null; then
                success "Git already configured: $current_name <$current_email>"
                read -rp "Reconfigure? [y/N] " answer
                answer="${answer:-N}"
                if [[ ! "$answer" =~ ^[Yy]$ ]]; then
                    return 0
                fi
            fi
        fi
    fi

    # Get current values as defaults
    local current_name current_email
    current_name="$(git config --global user.name 2>/dev/null || echo '')"
    current_email="$(git config --global user.email 2>/dev/null || echo '')"

    read -rp "Git user name [${current_name:-your name}]: " git_name
    git_name="${git_name:-$current_name}"

    read -rp "Git user email [${current_email:-your email}]: " git_email
    git_email="${git_email:-$current_email}"

    if [[ -z "$git_name" || -z "$git_email" ]]; then
        warn "Name and email required, skipping git config"
        return 0
    fi

    # Backup existing
    if [[ -f "$gitconfig_dst" ]]; then
        local backup="${gitconfig_dst}.bak.$(date +%Y%m%d%H%M%S)"
        cp "$gitconfig_dst" "$backup"
        info "Backed up existing .gitconfig to $backup"
    fi

    # Render template
    sed -e "s|__GIT_NAME__|${git_name}|g" \
        -e "s|__GIT_EMAIL__|${git_email}|g" \
        "$gitconfig_src" > "$gitconfig_dst"

    # Deploy global gitignore
    if [[ -f "$DOTFILES_DIR/.gitignore" ]]; then
        cp "$DOTFILES_DIR/.gitignore" "$gitignore_dst"
        success "Deployed global .gitignore_global"
    fi

    success "Git configured: $git_name <$git_email>"
}

# ============================================================
# Step 6: Configure bash
# ============================================================

setup_bash() {
    header "Step 6: Bash Configuration"

    local bashrc="$HOME/.bashrc"
    local marker="# >>> dotfiles >>>"
    local marker_end="# <<< dotfiles <<<"

    # Check if already configured
    if [[ -f "$bashrc" ]] && grep -qF "$marker" "$bashrc"; then
        success "Dotfiles already sourced in $bashrc"
        info "To re-apply, remove the dotfiles block from $bashrc and re-run"
        return 0
    fi

    # Backup existing .bashrc
    if [[ -f "$bashrc" ]]; then
        local backup="${bashrc}.bak.$(date +%Y%m%d%H%M%S)"
        cp "$bashrc" "$backup"
        info "Backed up existing .bashrc to $backup"
    fi

    # Append source block
    cat >> "$bashrc" << 'BASHRC_BLOCK'

# >>> dotfiles >>>
# Managed by https://github.com/zhiqiang-hhhh/dotfiles
# Do not edit this block manually.
export DOTFILES_DIR="$HOME/code/dotfiles"
if [[ -d "$DOTFILES_DIR/bashrc.d" ]]; then
    for _dotfile in "$DOTFILES_DIR/bashrc.d"/*.sh; do
        [[ -f "$_dotfile" ]] && source "$_dotfile"
    done
    unset _dotfile
fi
# <<< dotfiles <<<
BASHRC_BLOCK

    success "Added dotfiles source block to $bashrc"
    info "Your original .bashrc content is preserved above the block"
}

# ============================================================
# Step 7: Install development tools
# ============================================================

setup_tools() {
    header "Step 7: Development Tools"

    echo "Available tools to install:"
    echo "  1) JDK 17"
    echo "  2) Maven 3.9.x"
    echo "  3) ldb_toolchain (C/C++ build toolchain)"
    echo "  4) anaconda/conda (binary only)"
    echo "  5) rclone (binary only)"
    echo "  a) All of the above"
    echo "  n) Skip all"
    echo
    read -rp "Which tools to install? [a/1/2/3/4/5/n] " tools_choice
    tools_choice="${tools_choice:-a}"

    case "$tools_choice" in
        a|A)
            source "$DOTFILES_DIR/install/java.sh"          && install_java          || warn "JDK installation had issues"
            source "$DOTFILES_DIR/install/maven.sh"         && install_maven         || warn "Maven installation had issues"
            source "$DOTFILES_DIR/install/ldb_toolchain.sh" && install_ldb_toolchain || warn "ldb_toolchain installation had issues"
            source "$DOTFILES_DIR/install/anaconda.sh"      && install_anaconda      || warn "anaconda installation had issues"
            source "$DOTFILES_DIR/install/rclone.sh"        && install_rclone        || warn "rclone installation had issues"
            ;;
        n|N)
            info "Skipping tool installation"
            ;;
        *)
            # Support combinations like "12", "13", "123" etc.
            if [[ "$tools_choice" == *1* ]]; then
                source "$DOTFILES_DIR/install/java.sh" && install_java || warn "JDK installation had issues"
            fi
            if [[ "$tools_choice" == *2* ]]; then
                source "$DOTFILES_DIR/install/maven.sh" && install_maven || warn "Maven installation had issues"
            fi
            if [[ "$tools_choice" == *3* ]]; then
                source "$DOTFILES_DIR/install/ldb_toolchain.sh" && install_ldb_toolchain || warn "ldb_toolchain installation had issues"
            fi
            if [[ "$tools_choice" == *4* ]]; then
                source "$DOTFILES_DIR/install/anaconda.sh" && install_anaconda || warn "anaconda installation had issues"
            fi
            if [[ "$tools_choice" == *5* ]]; then
                source "$DOTFILES_DIR/install/rclone.sh" && install_rclone || warn "rclone installation had issues"
            fi
            ;;
    esac
}

# ============================================================
# Step 8: Clone repos from repos.conf
# ============================================================

setup_repos() {
    header "Step 8: Clone Repositories"

    local repos_conf="$DOTFILES_DIR/repos.conf"

    if [[ ! -f "$repos_conf" ]]; then
        warn "repos.conf not found, skipping"
        return 0
    fi

    # Count non-empty, non-comment lines
    local repo_count
    repo_count=$(grep -cvE '^\s*($|#)' "$repos_conf" || true)
    # Ensure it's a clean integer
    repo_count="${repo_count//[^0-9]/}"
    repo_count="${repo_count:-0}"

    if [[ "$repo_count" -eq 0 ]]; then
        info "No repos configured in repos.conf"
        info "Add repos later: edit $repos_conf"
        return 0
    fi

    info "Found $repo_count repo(s) in repos.conf"
    if ! confirm "Clone them now?"; then
        info "Skipping repo cloning"
        return 0
    fi

    local clone_count=0
    local skip_count=0
    local fail_count=0

    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

        # Parse: <repo_url> [custom_dir]
        local repo_url custom_dir repo_name target_dir
        repo_url="$(echo "$line" | awk '{print $1}')"
        custom_dir="$(echo "$line" | awk '{print $2}')"

        # Extract repo name from URL
        repo_name="$(basename "$repo_url" .git)"

        if [[ -n "$custom_dir" ]]; then
            target_dir="$HOME/code/$custom_dir"
        else
            target_dir="$HOME/code/$repo_name"
        fi

        if [[ -d "$target_dir" ]]; then
            success "Already exists: $target_dir"
            skip_count=$((skip_count + 1))
            continue
        fi

        info "Cloning $repo_url -> $target_dir"
        if git clone "$repo_url" "$target_dir"; then
            success "Cloned: $repo_name"
            clone_count=$((clone_count + 1))
        else
            warn "Failed to clone: $repo_url"
            fail_count=$((fail_count + 1))
        fi
    done < "$repos_conf"

    echo
    info "Clone summary: $clone_count cloned, $skip_count skipped, $fail_count failed"
}

# ============================================================
# Step 9: Install Doris thirdparty prebuilt
# ============================================================

setup_doris_thirdparty() {
    header "Step 9: Doris Thirdparty Dependencies"

    if [[ ! -d "$HOME/code/doris" ]]; then
        warn "Doris repo not found at ~/code/doris — skipping thirdparty setup"
        info "Clone it first, then run: bash $DOTFILES_DIR/install/doris-thirdparty.sh"
        return 0
    fi

    if ! confirm "Install Doris thirdparty prebuilt dependencies?"; then
        info "Skipping Doris thirdparty"
        return 0
    fi

    source "$DOTFILES_DIR/install/doris-thirdparty.sh" && install_doris_thirdparty || warn "Doris thirdparty installation had issues"
}

# ============================================================
# Step 10: Prepare Doris workspace runtime layout
# ============================================================

setup_doris_workspace() {
    header "Step 10: Doris Workspace Runtime"

    if [[ ! -d "$HOME/code/doris" ]]; then
        warn "Doris repo not found at ~/code/doris — skipping workspace setup"
        info "Clone Doris and build it first, then run: bash $DOTFILES_DIR/install/doris-workspace.sh"
        return 0
    fi

    if [[ ! -d "$HOME/code/doris/output/fe" || ! -d "$HOME/code/doris/output/be" ]]; then
        warn "Doris output not found at ~/code/doris/output/{fe,be} — skipping workspace setup"
        info "Build Doris first, then run: bash $DOTFILES_DIR/install/doris-workspace.sh"
        return 0
    fi

    if ! confirm "Prepare ~/workspace/doris runtime layout (symlink FE/BE bin and FE/BE lib)?"; then
        info "Skipping Doris workspace setup"
        return 0
    fi

    source "$DOTFILES_DIR/install/doris-workspace.sh" && install_doris_workspace || warn "Doris workspace setup had issues"
}

# ============================================================
# Summary
# ============================================================

print_summary() {
    header "Setup Complete!"

    echo "Directory structure:"
    echo "  ~/code/        - Your code repositories"
    echo "  ~/workspace/   - Project deployment & runtime directories"
    echo "  ~/tools/       - Build tools (JDK, Maven, ldb_toolchain)"
    echo "  ~/bin/         - Your custom scripts"
    echo "  ~/downloads/   - Downloaded archives & prebuilts"
    echo
    echo "Dotfiles location: $DOTFILES_DIR"
    echo
    echo "Quick commands (after sourcing bashrc):"
    echo "  c <dir>     - cd to ~/code/<dir>      (Tab completion)"
    echo "  w <dir>     - cd to ~/workspace/<dir>  (Tab completion)"
    echo "  t <dir>     - cd to ~/tools/<dir>      (Tab completion)"
    echo "  gs/gd/gl    - git status/diff/log"
    echo "  mkcd <dir>  - mkdir + cd"
    echo "  extract <f> - extract any archive"
    echo
    echo "To apply changes now, run:"
    echo
    echo "  source ~/.bashrc"
    echo
    echo "To add more repos later, edit:"
    echo "  $DOTFILES_DIR/repos.conf"
    echo
    echo "To re-run individual installers:"
    echo "  bash $DOTFILES_DIR/install/java.sh"
    echo "  bash $DOTFILES_DIR/install/maven.sh"
    echo "  bash $DOTFILES_DIR/install/ldb_toolchain.sh"
    echo "  bash $DOTFILES_DIR/install/anaconda.sh"
    echo "  bash $DOTFILES_DIR/install/rclone.sh"
    echo "  bash $DOTFILES_DIR/install/doris-thirdparty.sh"
    echo "  bash $DOTFILES_DIR/install/doris-workspace.sh"
    echo
}

# ============================================================
# Main
# ============================================================

main() {
    echo
    echo "  ┌──────────────────────────────────────────┐"
    echo "  │  Development Machine Bootstrap            │"
    echo "  │  github.com/zhiqiang-hhhh/dotfiles        │"
    echo "  └──────────────────────────────────────────┘"
    echo

    info "HOME directory: $HOME"
    echo

    if ! confirm "Start setup?"; then
        info "Aborted."
        exit 0
    fi

    setup_directories       # Step 1
    setup_git_install       # Step 2
    setup_ssh               # Step 3
    setup_clone_dotfiles    # Step 4
    setup_git_config        # Step 5
    setup_bash              # Step 6
    setup_tools             # Step 7
    setup_repos             # Step 8
    setup_doris_thirdparty  # Step 9
    setup_doris_workspace   # Step 10
    print_summary           # Done
}

main "$@"
