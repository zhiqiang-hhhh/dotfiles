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
    fi
    unset _java_home
fi

# Maven
if [[ -d "$HOME/tools/maven" ]]; then
    export MAVEN_HOME="$HOME/tools/maven"
    export M2_HOME="$MAVEN_HOME"
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
shopt -s histappend  # Append to history instead of overwriting
