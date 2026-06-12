#!/usr/bin/env bash

clickhouse_workspace_dir() {
    printf '%s\n' "${CLICKHOUSE_WORKSPACE:-$HOME/workspace/clickhouse}"
}

clickhouse_zookeeper_home() {
    if [[ -n "${ZOOKEEPER_HOME:-}" ]]; then
        printf '%s\n' "$ZOOKEEPER_HOME"
        return 0
    fi

    local candidate
    candidate="$(find "$HOME/workspace/zookeeper" -maxdepth 1 -type d -name 'apache-zookeeper-*-bin' 2>/dev/null | sort | tail -n1 || true)"
    if [[ -n "$candidate" ]]; then
        printf '%s\n' "$candidate"
        return 0
    fi

    printf '%s\n' "$HOME/workspace/zookeeper/apache-zookeeper-3.8.6-bin"
}

clickhouse_binary() {
    printf '%s\n' "${CLICKHOUSE_BINARY:-$(clickhouse_workspace_dir)/bin/clickhouse}"
}

clickhouse_config_path() {
    local node="${1:-single}"
    local workspace
    workspace="$(clickhouse_workspace_dir)"

    case "$node" in
        single|default)
            printf '%s\n' "$workspace/conf/config.xml"
            ;;
        node1|node2)
            printf '%s\n' "$workspace/conf/${node}.xml"
            ;;
        *)
            echo "unknown ClickHouse node: $node" >&2
            echo "expected one of: single, node1, node2, all" >&2
            return 1
            ;;
    esac
}

clickhouse_nodes_from_args() {
    if [[ "$#" -eq 0 ]]; then
        if [[ -f "$(clickhouse_config_path node1)" || -f "$(clickhouse_config_path node2)" ]]; then
            printf '%s\n' node1 node2
        else
            printf '%s\n' single
        fi
        return 0
    fi

    local arg
    for arg in "$@"; do
        case "$arg" in
            all)
                printf '%s\n' node1 node2
                ;;
            single|default|node1|node2)
                printf '%s\n' "$arg"
                ;;
            *)
                echo "unknown ClickHouse node selector: $arg" >&2
                echo "expected one of: all, single, node1, node2" >&2
                return 1
                ;;
        esac
    done
}

clickhouse_config_get() {
    local conf_file="$1"
    local key="$2"
    local default_value="${3:-}"

    if [[ ! -f "$conf_file" ]]; then
        printf '%s\n' "$default_value"
        return 0
    fi

    awk -v key="$key" -v default_value="$default_value" '
        {
            open = "<" key ">"
            close_tag = "</" key ">"
            start = index($0, open)
            stop = index($0, close_tag)
            if (start && stop && stop > start) {
                value = substr($0, start + length(open), stop - start - length(open))
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
                print value
                found = 1
                exit
            }
        }
        END {
            if (!found) {
                print default_value
            }
        }
    ' "$conf_file"
}

clickhouse_pid_file() {
    local node="$1"
    printf '%s\n' "$(clickhouse_workspace_dir)/run/${node}.pid"
}

clickhouse_process_pids() {
    local node="$1"
    local conf_file
    local pid_file
    conf_file="$(clickhouse_config_path "$node")"
    pid_file="$(clickhouse_pid_file "$node")"

    {
        if [[ -f "$pid_file" ]]; then
            local pid
            pid="$(cat "$pid_file" 2>/dev/null || true)"
            if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                printf '%s\n' "$pid"
            fi
        fi

        if command -v pgrep >/dev/null 2>&1; then
            pgrep -f "clickhouse.*server.*--config-file=${conf_file}" 2>/dev/null || true
        else
            ps -eo pid=,command= | awk -v conf_file="$conf_file" '
                /clickhouse/ && /server/ && index($0, "--config-file=" conf_file) {
                    print $1
                }
            '
        fi
    } | awk '!seen[$0]++'
}

clickhouse_is_running() {
    local node="$1"
    [[ -n "$(clickhouse_process_pids "$node" | head -n1)" ]]
}

clickhouse_prepare_dirs_for_config() {
    local conf_file="$1"
    local log_file error_log path tmp_path user_files_path format_schema_path

    log_file="$(clickhouse_config_get "$conf_file" log "")"
    error_log="$(clickhouse_config_get "$conf_file" errorlog "")"
    path="$(clickhouse_config_get "$conf_file" path "")"
    tmp_path="$(clickhouse_config_get "$conf_file" tmp_path "")"
    user_files_path="$(clickhouse_config_get "$conf_file" user_files_path "")"
    format_schema_path="$(clickhouse_config_get "$conf_file" format_schema_path "")"

    [[ -n "$log_file" ]] && mkdir -p "$(dirname "$log_file")"
    [[ -n "$error_log" ]] && mkdir -p "$(dirname "$error_log")"
    [[ -n "$path" ]] && mkdir -p "$path"
    [[ -n "$tmp_path" ]] && mkdir -p "$tmp_path"
    [[ -n "$user_files_path" ]] && mkdir -p "$user_files_path"
    [[ -n "$format_schema_path" ]] && mkdir -p "$format_schema_path"

    mkdir -p "$(clickhouse_workspace_dir)/run"
}

clickhouse_wait_for_http() {
    local node="$1"
    local conf_file
    local port
    local i

    conf_file="$(clickhouse_config_path "$node")"
    port="$(clickhouse_config_get "$conf_file" http_port "")"
    if [[ -z "$port" ]] || ! command -v curl >/dev/null 2>&1; then
        return 0
    fi

    for i in $(seq 1 30); do
        if curl -fsS "http://127.0.0.1:${port}/ping" >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done

    echo "WARN: ClickHouse $node did not answer http://127.0.0.1:${port}/ping within 30s" >&2
    return 0
}

clickhouse_start_node() {
    local node="$1"
    local binary
    local conf_file
    local pid_file
    local stdout_file
    local stderr_file
    local old_pwd
    local pid

    binary="$(clickhouse_binary)"
    conf_file="$(clickhouse_config_path "$node")"
    pid_file="$(clickhouse_pid_file "$node")"
    stdout_file="$(clickhouse_workspace_dir)/logs/${node}/stdout.log"
    stderr_file="$(clickhouse_workspace_dir)/logs/${node}/stderr.log"

    if [[ ! -x "$binary" ]]; then
        echo "missing executable ClickHouse binary: $binary" >&2
        echo "run: deploy-ch" >&2
        return 1
    fi
    if [[ ! -f "$conf_file" ]]; then
        echo "missing ClickHouse config: $conf_file" >&2
        return 1
    fi
    if clickhouse_is_running "$node"; then
        echo "ClickHouse $node is already running: $(clickhouse_process_pids "$node" | paste -sd, -)"
        return 0
    fi

    clickhouse_prepare_dirs_for_config "$conf_file"
    mkdir -p "$(dirname "$stdout_file")" "$(dirname "$stderr_file")"

    echo "Starting ClickHouse $node with config: $conf_file"
    old_pwd="$PWD"
    cd "$(clickhouse_workspace_dir)"
    "$binary" server "--config-file=${conf_file}" >"$stdout_file" 2>"$stderr_file" &
    pid="$!"
    cd "$old_pwd"
    printf '%s\n' "$pid" > "$pid_file"

    sleep 1
    if ! kill -0 "$pid" 2>/dev/null; then
        echo "ClickHouse $node exited during startup; see $stderr_file" >&2
        return 1
    fi

    clickhouse_wait_for_http "$node"
    echo "ClickHouse $node started: pid=$pid"
}

clickhouse_stop_node() {
    local node="$1"
    local force="${2:-}"
    local pid_file
    local pids
    local pid
    local i

    pid_file="$(clickhouse_pid_file "$node")"
    pids="$(clickhouse_process_pids "$node" | paste -sd' ' -)"
    if [[ -z "$pids" ]]; then
        echo "ClickHouse $node is not running"
        rm -f "$pid_file"
        return 0
    fi

    echo "Stopping ClickHouse $node: $pids"
    for pid in $pids; do
        kill "$pid" 2>/dev/null || true
    done

    for i in $(seq 1 30); do
        local still_running=""
        for pid in $pids; do
            if kill -0 "$pid" 2>/dev/null; then
                still_running=1
            fi
        done
        [[ -z "$still_running" ]] && break
        sleep 1
    done

    if [[ "$force" == "--force" ]]; then
        for pid in $pids; do
            kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null || true
        done
    fi

    rm -f "$pid_file"
}

clickhouse_status_node() {
    local node="$1"
    local conf_file
    local http_port
    local tcp_port
    local pids

    conf_file="$(clickhouse_config_path "$node")"
    http_port="$(clickhouse_config_get "$conf_file" http_port "-")"
    tcp_port="$(clickhouse_config_get "$conf_file" tcp_port "-")"
    pids="$(clickhouse_process_pids "$node" | paste -sd, -)"

    if [[ -n "$pids" ]]; then
        printf '%-8s running  pid=%s  http=%s  tcp=%s\n' "$node" "$pids" "$http_port" "$tcp_port"
    else
        printf '%-8s stopped  http=%s  tcp=%s\n' "$node" "$http_port" "$tcp_port"
    fi
}

zookeeper_server_script() {
    printf '%s\n' "$(clickhouse_zookeeper_home)/bin/zkServer.sh"
}

zookeeper_config_path() {
    printf '%s\n' "$(clickhouse_zookeeper_home)/conf/zoo.cfg"
}

zookeeper_conf_get() {
    local key="$1"
    local default_value="${2:-}"
    local config_file
    local line

    config_file="$(zookeeper_config_path)"
    if [[ ! -f "$config_file" ]]; then
        printf '%s\n' "$default_value"
        return 0
    fi

    line="$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "$config_file" | tail -n1 || true)"
    if [[ -z "$line" ]]; then
        printf '%s\n' "$default_value"
        return 0
    fi

    line="${line#*=}"
    line="${line%%#*}"
    line="$(printf '%s' "$line" | xargs)"
    printf '%s\n' "$line"
}

zookeeper_pid_file() {
    local data_dir
    data_dir="$(zookeeper_conf_get dataDir "$(clickhouse_zookeeper_home)/data")"
    printf '%s\n' "$data_dir/zookeeper_server.pid"
}

zookeeper_process_pids() {
    local pid_file
    pid_file="$(zookeeper_pid_file)"

    {
        if [[ -f "$pid_file" ]]; then
            local pid
            pid="$(cat "$pid_file" 2>/dev/null || true)"
            if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                printf '%s\n' "$pid"
            fi
        fi

        if command -v pgrep >/dev/null 2>&1; then
            pgrep -f "org.apache.zookeeper.server.quorum.QuorumPeerMain.*$(zookeeper_config_path)" 2>/dev/null || true
        fi
    } | awk '!seen[$0]++'
}

zookeeper_port_open() {
    local port
    port="$(zookeeper_conf_get clientPort "2181")"

    if command -v nc >/dev/null 2>&1; then
        nc -z 127.0.0.1 "$port" >/dev/null 2>&1
        return $?
    fi

    return 1
}

zookeeper_is_running() {
    [[ -n "$(zookeeper_process_pids | head -n1)" ]] || zookeeper_port_open
}

zookeeper_status_summary() {
    local port
    local pids
    port="$(zookeeper_conf_get clientPort "2181")"
    pids="$(zookeeper_process_pids | paste -sd, -)"

    if zookeeper_is_running; then
        if [[ -n "$pids" ]]; then
            echo "ZooKeeper running: pid=$pids client_port=$port"
        else
            echo "ZooKeeper running: client_port=$port"
        fi
        return 0
    fi

    echo "ZooKeeper stopped: client_port=$port"
    return 1
}

zookeeper_start() {
    local server_script
    local config_file
    local i
    server_script="$(zookeeper_server_script)"
    config_file="$(zookeeper_config_path)"

    if [[ ! -x "$server_script" ]]; then
        echo "missing executable ZooKeeper server script: $server_script" >&2
        return 1
    fi
    if [[ ! -f "$config_file" ]]; then
        echo "missing ZooKeeper config: $config_file" >&2
        return 1
    fi

    if zookeeper_is_running; then
        zookeeper_status_summary
        return 0
    fi

    echo "Starting ZooKeeper with config: $config_file"
    "$server_script" start "$config_file"

    for i in $(seq 1 20); do
        if zookeeper_is_running; then
            sleep 10
            if ! zookeeper_is_running; then
                echo "ZooKeeper process exited shortly after startup" >&2
                echo "Check logs under: $(clickhouse_zookeeper_home)/logs" >&2
                return 1
            fi
            zookeeper_status_summary
            return 0
        fi
        sleep 1
    done

    echo "ZooKeeper did not become reachable within 20s" >&2
    echo "Check logs under: $(clickhouse_zookeeper_home)/logs" >&2
    return 1
}

zookeeper_stop() {
    local server_script
    local config_file
    server_script="$(zookeeper_server_script)"
    config_file="$(zookeeper_config_path)"

    if [[ ! -x "$server_script" ]]; then
        echo "missing executable ZooKeeper server script: $server_script" >&2
        return 1
    fi

    "$server_script" stop "$config_file"
}

zookeeper_status() {
    if [[ ! -x "$(zookeeper_server_script)" ]]; then
        echo "missing executable ZooKeeper server script: $(zookeeper_server_script)" >&2
        return 1
    fi

    zookeeper_status_summary || true
}
