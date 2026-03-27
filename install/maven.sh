#!/usr/bin/env bash
# install/maven.sh - Install Apache Maven 3.9.x to ~/tools/maven

set -euo pipefail

MAVEN_VERSION="${MAVEN_VERSION:-3.9.14}"
TOOLS_DIR="$HOME/tools"
MAVEN_INSTALL_DIR="$TOOLS_DIR/maven"

info()    { printf "\033[34m[INFO]\033[0m %s\n" "$1"; }
warn()    { printf "\033[33m[WARN]\033[0m %s\n" "$1"; }
success() { printf "\033[32m[ OK ]\033[0m %s\n" "$1"; }

install_maven() {
    echo
    info "=== Maven ${MAVEN_VERSION} Setup ==="
    echo

    # Check if maven is already installed in our tools dir
    if [[ -x "$MAVEN_INSTALL_DIR/bin/mvn" ]]; then
        local mvn_ver
        mvn_ver="$("$MAVEN_INSTALL_DIR/bin/mvn" --version 2>&1 | head -1)"
        success "Maven already installed: $mvn_ver"
        return 0
    fi

    # Check if maven is available system-wide
    if command -v mvn &>/dev/null; then
        local mvn_ver
        mvn_ver="$(mvn --version 2>&1 | head -1)"
        info "Maven found in system PATH: $mvn_ver"
        read -rp "Install Maven ${MAVEN_VERSION} to $MAVEN_INSTALL_DIR anyway? [y/N] " answer
        answer="${answer:-N}"
        if [[ ! "$answer" =~ ^[Yy]$ ]]; then
            success "Using system Maven"
            return 0
        fi
    else
        read -rp "Install Maven ${MAVEN_VERSION} to $MAVEN_INSTALL_DIR? [Y/n] " answer
        answer="${answer:-Y}"
        if [[ ! "$answer" =~ ^[Yy]$ ]]; then
            warn "Skipping Maven installation"
            return 0
        fi
    fi

    local download_url="https://dlcdn.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz"
    local tmp_file="/tmp/apache-maven-${MAVEN_VERSION}-bin.tar.gz"

    info "Downloading Maven ${MAVEN_VERSION}..."
    if command -v curl &>/dev/null; then
        curl -fSL "$download_url" -o "$tmp_file"
    elif command -v wget &>/dev/null; then
        wget -q "$download_url" -O "$tmp_file"
    else
        warn "Neither curl nor wget found. Please install Maven manually."
        return 1
    fi

    info "Extracting to $MAVEN_INSTALL_DIR..."
    mkdir -p "$TOOLS_DIR"
    rm -rf "$MAVEN_INSTALL_DIR"
    tar -xzf "$tmp_file" -C "$TOOLS_DIR"
    mv "$TOOLS_DIR/apache-maven-${MAVEN_VERSION}" "$MAVEN_INSTALL_DIR"
    rm -f "$tmp_file"

    if [[ -x "$MAVEN_INSTALL_DIR/bin/mvn" ]]; then
        success "Maven installed: $("$MAVEN_INSTALL_DIR/bin/mvn" --version 2>&1 | head -1)"
    else
        warn "Maven installation may have failed, check $MAVEN_INSTALL_DIR"
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/_common.sh"

    install_maven
    ensure_bashrc
    hint_source_bashrc
fi
