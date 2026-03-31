# bashrc.d/90-env.sh - Environment variables

# Editor
export EDITOR="${EDITOR:-vim}"
export VISUAL="${VISUAL:-vim}"

# Language / locale
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

# Java
if [[ -z "${JAVA_HOME:-}" ]]; then
    # Auto-detect JAVA_HOME on CentOS/RHEL
    _java_home=""
    if [[ -d "/usr/lib/jvm" ]]; then
        for d in /usr/lib/jvm/java-17* /usr/lib/jvm/jdk-17*; do
            if [[ -d "$d" ]]; then
                _java_home="$d"
                break
            fi
        done
    fi
    if [[ -n "$_java_home" ]]; then
        export JAVA_HOME="$_java_home"
    elif [[ -d "/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home" ]]; then
        export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
    elif [[ -d "/usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home" ]]; then
        export JAVA_HOME="/usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
    fi
    unset _java_home
fi

# Maven
if [[ -d "$HOME/tools/maven" ]]; then
    export MAVEN_HOME="$HOME/tools/maven"
    export M2_HOME="$MAVEN_HOME"
fi

# Go
if [[ -d "$HOME/tools/go" ]]; then
    export GOROOT="$HOME/tools/go"
fi
if [[ -z "${GOPATH:-}" ]]; then
    export GOPATH="$HOME/go"
fi

# ldb_toolchain
if [[ -d "$HOME/tools/ldb_toolchain" ]]; then
    export LDB_TOOLCHAIN_HOME="$HOME/tools/ldb_toolchain"
fi

# conda-standalone: force stable root prefix instead of transient /tmp/_MEI*
if [[ -d "$HOME/tools/anaconda" ]]; then
    export CONDA_ROOT_PREFIX="$HOME/tools/anaconda"
fi

# History settings
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoreboth:erasedups  # No duplicates, ignore leading space
export HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S  "
if command -v shopt >/dev/null 2>&1; then
    shopt -s histappend  # Append to history instead of overwriting
fi
