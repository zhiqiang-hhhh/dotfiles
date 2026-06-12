#!/usr/bin/env bash
#
# bin/_minio-common.sh - Shared helpers for the local MinIO instance
#
# Layout:
#   ~/tools/minio/minio        runtime server binary
#   ~/tools/minio/mc           client binary
#   ~/workspace/minio/data     object storage data
#   ~/workspace/minio/minio.conf  machine-local config (ports, credentials, bucket)
#   ~/workspace/minio/mc       mc client config dir (MC_CONFIG_DIR)
#

MINIO_TOOLS_DIR="${MINIO_TOOLS_DIR:-$HOME/tools/minio}"
MINIO_WORKSPACE_DIR="${MINIO_WORKSPACE_DIR:-$HOME/workspace/minio}"
MINIO_CONF_FILE="$MINIO_WORKSPACE_DIR/minio.conf"
MINIO_ALIAS="${MINIO_ALIAS:-local}"

if ! declare -f info &>/dev/null; then
    info()    { printf "\033[34m[INFO]\033[0m %s\n" "$1"; }
fi
if ! declare -f warn &>/dev/null; then
    warn()    { printf "\033[33m[WARN]\033[0m %s\n" "$1"; }
fi
if ! declare -f success &>/dev/null; then
    success() { printf "\033[32m[ OK ]\033[0m %s\n" "$1"; }
fi

minio_conf_path() {
    printf '%s\n' "$MINIO_CONF_FILE"
}

minio_conf_get() {
    local key="$1"
    local default_value="${2:-}"
    local line

    if [[ ! -f "$MINIO_CONF_FILE" ]]; then
        printf '%s\n' "$default_value"
        return 0
    fi

    line="$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "$MINIO_CONF_FILE" | tail -n1 || true)"
    if [[ -z "$line" ]]; then
        printf '%s\n' "$default_value"
        return 0
    fi

    line="${line#*=}"
    line="${line%%#*}"
    line="$(printf '%s' "$line" | xargs)"
    printf '%s\n' "$line"
}

minio_api_port()      { minio_conf_get "api_port" "19900"; }
minio_console_port()  { minio_conf_get "console_port" "19901"; }
minio_root_user()     { minio_conf_get "root_user" "minioadmin"; }
minio_root_password() { minio_conf_get "root_password" "minioadmin"; }
minio_bucket()        { minio_conf_get "bucket" "clickhouse"; }

minio_data_dir() {
    minio_conf_get "data_dir" "$MINIO_WORKSPACE_DIR/data"
}

minio_endpoint() {
    printf 'http://127.0.0.1:%s\n' "$(minio_api_port)"
}

minio_binary() {
    printf '%s\n' "$MINIO_TOOLS_DIR/minio"
}

minio_mc_binary() {
    printf '%s\n' "$MINIO_TOOLS_DIR/mc"
}

minio_pid_file() {
    printf '%s\n' "$MINIO_WORKSPACE_DIR/minio.pid"
}

minio_log_file() {
    printf '%s\n' "$MINIO_WORKSPACE_DIR/minio.log"
}

minio_get_pid() {
    local pid_file
    pid_file="$(minio_pid_file)"
    [[ -f "$pid_file" ]] && cat "$pid_file" 2>/dev/null
}

minio_is_running() {
    local pid_file pid
    pid_file="$(minio_pid_file)"

    if [[ ! -f "$pid_file" ]]; then
        return 1
    fi

    pid="$(cat "$pid_file" 2>/dev/null || true)"
    if [[ -z "$pid" ]]; then
        rm -f "$pid_file"
        return 1
    fi

    if kill -0 "$pid" 2>/dev/null; then
        return 0
    fi

    rm -f "$pid_file"
    return 1
}

# Run the mc client against the machine-local config dir so it never touches ~/.mc
minio_mc() {
    local mc
    mc="$(minio_mc_binary)"
    if [[ ! -x "$mc" ]]; then
        echo "missing executable mc client: $mc" >&2
        echo "run: deploy-minio" >&2
        return 1
    fi
    MC_CONFIG_DIR="$MINIO_WORKSPACE_DIR/mc" "$mc" "$@"
}

minio_wait_for_ready() {
    local port i
    port="$(minio_api_port)"

    if ! command -v curl >/dev/null 2>&1; then
        return 0
    fi

    for i in $(seq 1 30); do
        if curl -fsS "http://127.0.0.1:${port}/minio/health/ready" >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done

    warn "MinIO did not report healthy on http://127.0.0.1:${port} within 30s"
    return 1
}

minio_ensure_alias() {
    minio_mc alias set "$MINIO_ALIAS" \
        "$(minio_endpoint)" \
        "$(minio_root_user)" \
        "$(minio_root_password)" >/dev/null
}

minio_ensure_bucket() {
    local bucket
    bucket="$(minio_bucket)"
    minio_mc mb --ignore-existing "${MINIO_ALIAS}/${bucket}" >/dev/null
    success "MinIO bucket ready: ${MINIO_ALIAS}/${bucket}"
}

minio_start() {
    local binary data_dir api_port console_port pid_file log_file pid

    binary="$(minio_binary)"
    data_dir="$(minio_data_dir)"
    api_port="$(minio_api_port)"
    console_port="$(minio_console_port)"
    pid_file="$(minio_pid_file)"
    log_file="$(minio_log_file)"

    if [[ ! -x "$binary" ]]; then
        echo "missing executable MinIO server binary: $binary" >&2
        echo "run: deploy-minio" >&2
        return 1
    fi
    if [[ ! -f "$MINIO_CONF_FILE" ]]; then
        echo "missing MinIO config: $MINIO_CONF_FILE" >&2
        echo "run: deploy-minio" >&2
        return 1
    fi

    if minio_is_running; then
        info "MinIO is already running (PID $(minio_get_pid))"
        minio_ensure_alias && minio_ensure_bucket || true
        return 0
    fi

    mkdir -p "$data_dir" "$MINIO_WORKSPACE_DIR/mc"

    echo "Starting MinIO: api=127.0.0.1:${api_port} console=127.0.0.1:${console_port} data=${data_dir}"
    MINIO_ROOT_USER="$(minio_root_user)" \
    MINIO_ROOT_PASSWORD="$(minio_root_password)" \
        nohup "$binary" server "$data_dir" \
            --address "127.0.0.1:${api_port}" \
            --console-address "127.0.0.1:${console_port}" \
            > "$log_file" 2>&1 &
    pid="$!"
    echo "$pid" > "$pid_file"

    sleep 1
    if ! kill -0 "$pid" 2>/dev/null; then
        echo "MinIO exited during startup; see $log_file" >&2
        rm -f "$pid_file"
        return 1
    fi

    minio_wait_for_ready || true
    minio_ensure_alias && minio_ensure_bucket || warn "Could not initialize mc alias/bucket; check $log_file"

    success "MinIO started (PID $pid)"
    info "Console: http://127.0.0.1:${console_port}  (user $(minio_root_user))"
    info "S3 API:  $(minio_endpoint)"
}

minio_stop() {
    local pid pid_file elapsed=0
    pid_file="$(minio_pid_file)"

    if ! minio_is_running; then
        info "MinIO is not running"
        rm -f "$pid_file"
        return 0
    fi

    pid="$(minio_get_pid)"
    info "Stopping MinIO (PID ${pid}) ..."
    kill "$pid" 2>/dev/null || true

    while (( elapsed < 10 )); do
        kill -0 "$pid" 2>/dev/null || break
        sleep 1
        (( elapsed += 1 ))
    done

    if kill -0 "$pid" 2>/dev/null; then
        warn "MinIO did not stop gracefully, sending SIGKILL"
        kill -9 "$pid" 2>/dev/null || true
    fi

    rm -f "$pid_file"
    success "MinIO stopped"
}

minio_status() {
    local api_port console_port pid bucket

    api_port="$(minio_api_port)"
    console_port="$(minio_console_port)"
    bucket="$(minio_bucket)"

    if minio_is_running; then
        pid="$(minio_get_pid)"
        printf 'minio    running  pid=%s  api=%s  console=%s  bucket=%s\n' \
            "$pid" "$api_port" "$console_port" "$bucket"
    else
        printf 'minio    stopped  api=%s  console=%s  bucket=%s\n' \
            "$api_port" "$console_port" "$bucket"
    fi
}
