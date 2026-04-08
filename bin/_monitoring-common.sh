#!/usr/bin/env bash

MONITORING_TOOLS_DIR="$HOME/tools/monitoring"
MONITORING_WORKSPACE_DIR="$HOME/workspace/monitoring"
MONITORING_CONF_FILE="$MONITORING_WORKSPACE_DIR/monitoring.conf"

if ! declare -f info &>/dev/null; then
    info()    { printf "\033[34m[INFO]\033[0m %s\n" "$1"; }
fi
if ! declare -f warn &>/dev/null; then
    warn()    { printf "\033[33m[WARN]\033[0m %s\n" "$1"; }
fi
if ! declare -f success &>/dev/null; then
    success() { printf "\033[32m[ OK ]\033[0m %s\n" "$1"; }
fi

monitoring_conf_path() {
    printf '%s\n' "$MONITORING_CONF_FILE"
}

monitoring_conf_get() {
    local key="$1"
    local default_value="${2:-}"
    local line

    if [[ ! -f "$MONITORING_CONF_FILE" ]]; then
        printf '%s\n' "$default_value"
        return 0
    fi

    line="$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "$MONITORING_CONF_FILE" | tail -n1 || true)"
    if [[ -z "$line" ]]; then
        printf '%s\n' "$default_value"
        return 0
    fi

    line="${line#*=}"
    line="${line%%#*}"
    line="$(printf '%s' "$line" | xargs)"
    printf '%s\n' "$line"
}

monitoring_prometheus_port() {
    monitoring_conf_get "prometheus_port" "9090"
}

monitoring_grafana_port() {
    monitoring_conf_get "grafana_port" "3000"
}

monitoring_node_exporter_port() {
    monitoring_conf_get "node_exporter_port" "9100"
}

monitoring_prometheus_retention() {
    monitoring_conf_get "prometheus_retention" "15d"
}

monitoring_grafana_admin_user() {
    monitoring_conf_get "grafana_admin_user" "admin"
}

monitoring_grafana_admin_password() {
    monitoring_conf_get "grafana_admin_password" "admin"
}

monitoring_component_home() {
    local component="$1"
    case "$component" in
        prometheus|grafana|node_exporter)
            printf '%s\n' "$MONITORING_TOOLS_DIR/$component"
            ;;
        *)
            echo "unsupported monitoring component: $component" >&2
            return 1
            ;;
    esac
}

monitoring_component_workspace() {
    local component="$1"
    case "$component" in
        prometheus|grafana|node_exporter)
            printf '%s\n' "$MONITORING_WORKSPACE_DIR/$component"
            ;;
        *)
            echo "unsupported monitoring component: $component" >&2
            return 1
            ;;
    esac
}

monitoring_pid_file() {
    local component="$1"
    printf '%s\n' "$MONITORING_WORKSPACE_DIR/${component}.pid"
}

monitoring_get_pid() {
    local component="$1"
    local pid_file
    pid_file="$(monitoring_pid_file "$component")"
    [[ -f "$pid_file" ]] && cat "$pid_file" 2>/dev/null
}

monitoring_is_running() {
    local component="$1"
    local pid_file pid
    pid_file="$(monitoring_pid_file "$component")"

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

monitoring_start_component() {
    local component="$1"

    if monitoring_is_running "$component"; then
        info "${component} is already running (PID $(monitoring_get_pid "$component")), skip start"
        return 0
    fi

    local home_dir workspace_dir pid_file log_file
    home_dir="$(monitoring_component_home "$component")"
    workspace_dir="$(monitoring_component_workspace "$component")"
    pid_file="$(monitoring_pid_file "$component")"

    mkdir -p "$workspace_dir"

    case "$component" in
        prometheus)
            local prom_port prom_retention config_file data_dir
            prom_port="$(monitoring_prometheus_port)"
            prom_retention="$(monitoring_prometheus_retention)"
            config_file="$workspace_dir/prometheus.yml"
            data_dir="$workspace_dir/data"
            log_file="$workspace_dir/prometheus.log"

            [[ -x "$home_dir/prometheus" ]] || {
                echo "missing executable: $home_dir/prometheus" >&2
                return 1
            }
            [[ -f "$config_file" ]] || {
                echo "missing config: $config_file" >&2
                return 1
            }

            mkdir -p "$data_dir"
            nohup "$home_dir/prometheus" \
                --config.file="$config_file" \
                --storage.tsdb.path="$data_dir" \
                --storage.tsdb.retention.time="$prom_retention" \
                --web.listen-address="0.0.0.0:${prom_port}" \
                --web.enable-lifecycle \
                --web.console.templates="$home_dir/consoles" \
                --web.console.libraries="$home_dir/console_libraries" \
                > "$log_file" 2>&1 &
            ;;
        grafana)
            local grafana_config
            grafana_config="$workspace_dir/custom.ini"
            log_file="$workspace_dir/grafana.log"

            [[ -x "$home_dir/bin/grafana" ]] || {
                echo "missing executable: $home_dir/bin/grafana" >&2
                return 1
            }
            [[ -f "$grafana_config" ]] || {
                echo "missing config: $grafana_config" >&2
                return 1
            }

            nohup "$home_dir/bin/grafana" server \
                --config="$grafana_config" \
                --homepath="$home_dir" \
                > "$log_file" 2>&1 &
            ;;
        node_exporter)
            local ne_port
            ne_port="$(monitoring_node_exporter_port)"
            log_file="$workspace_dir/node_exporter.log"

            [[ -x "$home_dir/node_exporter" ]] || {
                echo "missing executable: $home_dir/node_exporter" >&2
                return 1
            }

            nohup "$home_dir/node_exporter" \
                --web.listen-address=":${ne_port}" \
                > "$log_file" 2>&1 &
            ;;
    esac

    echo $! > "$pid_file"
    sleep 1

    if monitoring_is_running "$component"; then
        success "${component} started (PID $(monitoring_get_pid "$component"))"
        return 0
    fi

    warn "${component} may have failed to start, check log: $log_file"
    return 1
}

monitoring_stop_component() {
    local component="$1"
    local pid pid_file
    pid_file="$(monitoring_pid_file "$component")"

    if ! monitoring_is_running "$component"; then
        info "${component} is not running, skip stop"
        return 0
    fi

    pid="$(monitoring_get_pid "$component")"
    info "Stopping ${component} (PID ${pid}) ..."
    kill "$pid" 2>/dev/null || true

    local elapsed=0
    while (( elapsed < 10 )); do
        if ! kill -0 "$pid" 2>/dev/null; then
            break
        fi
        sleep 1
        (( elapsed += 1 ))
    done

    if kill -0 "$pid" 2>/dev/null; then
        warn "${component} did not stop gracefully, sending SIGKILL"
        kill -9 "$pid" 2>/dev/null || true
    fi

    rm -f "$pid_file"
    success "${component} stopped"
}

monitoring_prometheus_reload() {
    local prom_port
    prom_port="$(monitoring_prometheus_port)"

    if curl -sf -X POST "http://127.0.0.1:${prom_port}/-/reload" >/dev/null 2>&1; then
        success "Prometheus configuration reloaded"
        return 0
    fi

    if monitoring_is_running prometheus; then
        kill -HUP "$(monitoring_get_pid prometheus)" 2>/dev/null || true
        success "Prometheus configuration reloaded (SIGHUP)"
        return 0
    fi

    warn "Prometheus is not running, cannot reload"
    return 1
}
