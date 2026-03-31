#!/usr/bin/env bash
# install/java.sh - Install JDK 17

set -euo pipefail

info()    { printf "\033[34m[INFO]\033[0m %s\n" "$1"; }
warn()    { printf "\033[33m[WARN]\033[0m %s\n" "$1"; }
success() { printf "\033[32m[ OK ]\033[0m %s\n" "$1"; }

install_java() {
    echo
    info "=== JDK 17 Setup ==="
    echo

    # Check if java 17 is already available
    if command -v java &>/dev/null; then
        local java_ver
        java_ver="$(java -version 2>&1 | head -1)"
        if echo "$java_ver" | grep -q '"17\.' ; then
            success "JDK 17 is already installed: $java_ver"
            return 0
        else
            info "Java found but not version 17: $java_ver"
        fi
    fi

    read -rp "Install JDK 17? [Y/n] " answer
    answer="${answer:-Y}"
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        warn "Skipping JDK 17 installation"
        return 0
    fi

    info "Installing JDK 17..."
    if command -v brew &>/dev/null; then
        brew install openjdk@17
        if [[ -d "/opt/homebrew/opt/openjdk@17" ]]; then
            info "Detected Homebrew OpenJDK path: /opt/homebrew/opt/openjdk@17"
            info "Consider adding to PATH if needed: export PATH=\"/opt/homebrew/opt/openjdk@17/bin:$PATH\""
        elif [[ -d "/usr/local/opt/openjdk@17" ]]; then
            info "Detected Homebrew OpenJDK path: /usr/local/opt/openjdk@17"
            info "Consider adding to PATH if needed: export PATH=\"/usr/local/opt/openjdk@17/bin:$PATH\""
        fi
    elif command -v yum &>/dev/null; then
        # Try different package names for CentOS/RHEL
        if yum list available java-17-openjdk-devel &>/dev/null 2>&1; then
            sudo yum install -y java-17-openjdk-devel
        elif yum list available java-17-amazon-corretto-devel &>/dev/null 2>&1; then
            sudo yum install -y java-17-amazon-corretto-devel
        else
            warn "JDK 17 package not found in yum repos."
            info "You can install manually, e.g.:"
            info "  sudo yum install -y java-17-openjdk-devel"
            info "  or download from https://adoptium.net/"
            return 1
        fi
    elif command -v apt-get &>/dev/null; then
        sudo apt-get update && sudo apt-get install -y openjdk-17-jdk
    else
        warn "Could not detect package manager. Please install JDK 17 manually."
        return 1
    fi

    # Verify installation
    if command -v java &>/dev/null; then
        success "JDK 17 installed: $(java -version 2>&1 | head -1)"
    else
        warn "Java command not found after installation, check your PATH"
    fi

    # Detect JAVA_HOME
    local java_home=""
    if [[ -d "/usr/lib/jvm" ]]; then
        java_home="$(find /usr/lib/jvm -maxdepth 1 -name 'java-17*' -type d | head -1)"
    elif [[ -d "/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home" ]]; then
        java_home="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
    elif [[ -d "/usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home" ]]; then
        java_home="/usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
    fi
    if [[ -n "$java_home" ]]; then
        info "Detected JAVA_HOME: $java_home"
        info "This will be set in bashrc.d/90-env.sh"
    fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$SCRIPT_DIR/_common.sh"

    install_java
    ensure_bashrc
    hint_source_bashrc
fi
