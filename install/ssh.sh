#!/usr/bin/env bash
# install/ssh.sh - Generate SSH key and guide user to add it to GitHub

set -euo pipefail

info()    { printf "\033[34m[INFO]\033[0m %s\n" "$1"; }
warn()    { printf "\033[33m[WARN]\033[0m %s\n" "$1"; }
success() { printf "\033[32m[ OK ]\033[0m %s\n" "$1"; }

setup_ssh() {
    local ssh_key="$HOME/.ssh/id_ed25519"

    echo
    info "=== SSH Key Setup ==="
    echo

    if [[ -f "$ssh_key" ]]; then
        success "SSH key already exists: $ssh_key"
        info "Public key:"
        echo
        cat "${ssh_key}.pub"
        echo
        return 0
    fi

    info "No SSH key found at $ssh_key"
    read -rp "Generate a new ed25519 SSH key? [Y/n] " answer
    answer="${answer:-Y}"
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        warn "Skipping SSH key generation"
        return 0
    fi

    read -rp "Enter email for SSH key (e.g. your GitHub email): " ssh_email
    if [[ -z "$ssh_email" ]]; then
        warn "No email provided, skipping SSH key generation"
        return 0
    fi

    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    ssh-keygen -t ed25519 -C "$ssh_email" -f "$ssh_key"

    # Start ssh-agent and add key
    eval "$(ssh-agent -s)" >/dev/null 2>&1 || true
    ssh-add "$ssh_key" 2>/dev/null || true

    success "SSH key generated successfully!"
    echo
    info "=== Your public key (copy this to GitHub) ==="
    echo
    echo "  $(cat "${ssh_key}.pub")"
    echo
    info "Add this key at: https://github.com/settings/keys"
    echo
    read -rp "Press Enter after you've added the key to GitHub... " _
    echo

    # Test GitHub connection
    info "Testing GitHub SSH connection..."
    if ssh -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        success "GitHub SSH connection verified!"
    else
        warn "Could not verify GitHub connection (this is normal if key was just added)."
        warn "You can test later with: ssh -T git@github.com"
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    setup_ssh
fi
