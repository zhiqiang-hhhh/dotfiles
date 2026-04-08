#!/usr/bin/env bash
# install/monitoring.sh - Install Prometheus, Grafana, and Node Exporter

if [[ -z "${BASH_VERSION:-}" ]]; then
    exec bash "$0" "$@"
fi

set -euo pipefail

if ! declare -f info &>/dev/null; then
    info()    { printf "\033[34m[INFO]\033[0m %s\n" "$1"; }
    warn()    { printf "\033[33m[WARN]\033[0m %s\n" "$1"; }
    success() { printf "\033[32m[ OK ]\033[0m %s\n" "$1"; }
fi

PROMETHEUS_VERSION="${PROMETHEUS_VERSION:-2.53.3}"
GRAFANA_VERSION="${GRAFANA_VERSION:-11.4.0}"
NODE_EXPORTER_VERSION="${NODE_EXPORTER_VERSION:-1.8.2}"

MONITORING_TOOLS_DIR="$HOME/tools/monitoring"
MONITORING_WORKSPACE_DIR="$HOME/workspace/monitoring"
MONITORING_DOWNLOAD_DIR="$HOME/downloads/monitoring"
MONITORING_PROMETHEUS_UID="local-prometheus"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
REPO_DORIS_DASHBOARD_SOURCE="$REPO_ROOT/monitoring/dashboards/doris-overview.raw.json"

_monitoring_detect_os() {
    case "$(uname -s)" in
        Linux) echo "linux" ;;
        Darwin) echo "darwin" ;;
        *)
            warn "Unsupported OS: $(uname -s)"
            return 1
            ;;
    esac
}

_monitoring_detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        *)
            warn "Unsupported architecture: $(uname -m)"
            return 1
            ;;
    esac
}

_download_if_missing() {
    local url="$1"
    local output="$2"

    if [[ -f "$output" ]]; then
        info "Archive already exists: $output"
        return 0
    fi

    info "Downloading: $url"
    if ! curl -fSL --progress-bar -o "$output.tmp" "$url"; then
        rm -f "$output.tmp"
        return 1
    fi
    mv "$output.tmp" "$output"
    success "Downloaded: $output"
}

_extract_dir_if_needed() {
    local archive="$1"
    local extracted_dir="$2"
    local target_dir="$3"

    if [[ -d "$target_dir" ]]; then
        return 0
    fi

    mkdir -p "$MONITORING_TOOLS_DIR"
    tar -xzf "$archive" -C "$MONITORING_TOOLS_DIR"
    mv "$MONITORING_TOOLS_DIR/$extracted_dir" "$target_dir"
}

_write_monitoring_conf_if_absent() {
    local conf_file="$MONITORING_WORKSPACE_DIR/monitoring.conf"
    if [[ -f "$conf_file" ]]; then
        return 0
    fi

    cat > "$conf_file" <<'EOF'
# Monitoring stack configuration
# Edit this file and rerun: bash ~/code/dotfiles/install/monitoring.sh

prometheus_port = 9090
prometheus_retention = 15d

grafana_port = 3000
grafana_admin_user = admin
grafana_admin_password = admin

node_exporter_port = 9100
EOF
    success "Initialized monitoring config: $conf_file"
}

_render_prometheus_config() {
    local prom_dir="$MONITORING_WORKSPACE_DIR/prometheus"
    local prom_port="$1"
    local ne_port="$2"

    mkdir -p "$prom_dir/data"
    cat > "$prom_dir/prometheus.yml" <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  scrape_timeout: 10s

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:${prom_port}"]

  - job_name: "node_exporter"
    static_configs:
      - targets: ["127.0.0.1:${ne_port}"]
EOF
    success "Generated Prometheus config"
}

_render_grafana_config() {
    local grafana_dir="$MONITORING_WORKSPACE_DIR/grafana"
    local grafana_port="$1"
    local prom_port="$2"
    local admin_user="$3"
    local admin_password="$4"

    mkdir -p "$grafana_dir/data/plugins" "$grafana_dir/data/log"
    mkdir -p "$grafana_dir/provisioning/datasources"
    mkdir -p "$grafana_dir/provisioning/dashboards/json"

    cat > "$grafana_dir/custom.ini" <<EOF
[paths]
data = ${grafana_dir}/data
logs = ${grafana_dir}/data/log
plugins = ${grafana_dir}/data/plugins
provisioning = ${grafana_dir}/provisioning

[server]
protocol = http
http_addr = 0.0.0.0
http_port = ${grafana_port}
domain = 127.0.0.1

[database]
type = sqlite3
path = ${grafana_dir}/data/grafana.db

[security]
admin_user = ${admin_user}
admin_password = ${admin_password}
allow_embedding = true

[users]
allow_sign_up = false

[auth.anonymous]
enabled = false

[log]
mode = file console
level = info
EOF

    cat > "$grafana_dir/provisioning/datasources/prometheus.yml" <<EOF
apiVersion: 1

datasources:
  - name: Prometheus
    uid: ${MONITORING_PROMETHEUS_UID}
    type: prometheus
    access: proxy
    url: http://127.0.0.1:${prom_port}
    isDefault: true
    editable: true
    jsonData:
      timeInterval: "15s"
      httpMethod: POST
EOF

    cat > "$grafana_dir/provisioning/dashboards/default.yml" <<EOF
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    editable: true
    updateIntervalSeconds: 30
    options:
      path: ${grafana_dir}/provisioning/dashboards/json
      foldersFromFilesStructure: false
EOF

    success "Generated Grafana config"
}

_install_bundled_dashboards() {
    local grafana_dashboard_dir="$MONITORING_WORKSPACE_DIR/grafana/provisioning/dashboards/json"

    mkdir -p "$grafana_dashboard_dir"

    if [[ -s "$REPO_DORIS_DASHBOARD_SOURCE" ]]; then
        cp "$REPO_DORIS_DASHBOARD_SOURCE" "$grafana_dashboard_dir/doris-overview.raw.json"
        success "Installed bundled Doris dashboard source"
    fi
}

_download_dashboard_if_missing() {
    local url="$1"
    local output="$2"
    local uid="$3"
    local title="$4"
    local tmp_file

    if [[ -s "$output" ]]; then
        return 0
    fi

    tmp_file="${output}.tmp"
    if ! curl -sf --connect-timeout 15 --max-time 60 -o "$tmp_file" "$url"; then
        rm -f "$tmp_file"
        return 1
    fi

    python3 - "$tmp_file" "$output" "$uid" "$title" "$MONITORING_PROMETHEUS_UID" <<'PY'
import json
import pathlib
import sys

src = pathlib.Path(sys.argv[1])
dst = pathlib.Path(sys.argv[2])
uid = sys.argv[3]
title = sys.argv[4]
prom_uid = sys.argv[5]
dashboard = json.loads(src.read_text())

def fix(obj):
    if isinstance(obj, dict):
        if 'datasource' in obj:
            ds = obj['datasource']
            if isinstance(ds, str):
                obj['datasource'] = {'type': 'prometheus', 'uid': prom_uid}
            elif isinstance(ds, dict):
                ds['type'] = 'prometheus'
                ds['uid'] = prom_uid
        for value in obj.values():
            fix(value)
    elif isinstance(obj, list):
        for item in obj:
            fix(item)

fix(dashboard)
dashboard['id'] = None
dashboard['uid'] = uid
dashboard['title'] = title
dashboard.pop('__inputs', None)
dst.write_text(json.dumps(dashboard, indent=2))
PY
    rm -f "$tmp_file"
    success "Prepared dashboard: $title"
}

install_monitoring() {
    local os arch
    os="$(_monitoring_detect_os)" || return 0
    arch="$(_monitoring_detect_arch)" || return 0

    local prom_archive prom_dir_name prom_target
    local grafana_archive grafana_dir_name grafana_target
    local ne_archive ne_dir_name ne_target

    prom_archive="$MONITORING_DOWNLOAD_DIR/prometheus-${PROMETHEUS_VERSION}.${os}-${arch}.tar.gz"
    prom_dir_name="prometheus-${PROMETHEUS_VERSION}.${os}-${arch}"
    prom_target="$MONITORING_TOOLS_DIR/prometheus"

    grafana_archive="$MONITORING_DOWNLOAD_DIR/grafana-${GRAFANA_VERSION}.${os}-${arch}.tar.gz"
    grafana_dir_name="grafana-v${GRAFANA_VERSION}"
    grafana_target="$MONITORING_TOOLS_DIR/grafana"

    ne_archive="$MONITORING_DOWNLOAD_DIR/node_exporter-${NODE_EXPORTER_VERSION}.${os}-${arch}.tar.gz"
    ne_dir_name="node_exporter-${NODE_EXPORTER_VERSION}.${os}-${arch}"
    ne_target="$MONITORING_TOOLS_DIR/node_exporter"

    mkdir -p "$MONITORING_DOWNLOAD_DIR" "$MONITORING_TOOLS_DIR" "$MONITORING_WORKSPACE_DIR"

    if [[ ! -x "$prom_target/prometheus" ]] || ! "$prom_target/prometheus" --version 2>&1 | grep -q "version ${PROMETHEUS_VERSION}"; then
        _download_if_missing "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/${prom_dir_name}.tar.gz" "$prom_archive"
        rm -rf "$prom_target"
        _extract_dir_if_needed "$prom_archive" "$prom_dir_name" "$prom_target"
        success "Installed Prometheus ${PROMETHEUS_VERSION}"
    else
        success "Prometheus already installed"
    fi

    if [[ ! -x "$grafana_target/bin/grafana" ]] || ! "$grafana_target/bin/grafana" server -v 2>&1 | grep -q "${GRAFANA_VERSION}"; then
        _download_if_missing "https://dl.grafana.com/oss/release/grafana-${GRAFANA_VERSION}.${os}-${arch}.tar.gz" "$grafana_archive"
        rm -rf "$grafana_target"
        tar -xzf "$grafana_archive" -C "$MONITORING_TOOLS_DIR"
        if [[ -d "$MONITORING_TOOLS_DIR/grafana-${GRAFANA_VERSION}" ]]; then
            mv "$MONITORING_TOOLS_DIR/grafana-${GRAFANA_VERSION}" "$grafana_target"
        elif [[ -d "$MONITORING_TOOLS_DIR/${grafana_dir_name}" ]]; then
            mv "$MONITORING_TOOLS_DIR/${grafana_dir_name}" "$grafana_target"
        else
            local extracted
            extracted="$(ls -d "$MONITORING_TOOLS_DIR"/grafana* 2>/dev/null | head -1 || true)"
            [[ -n "$extracted" ]] && mv "$extracted" "$grafana_target"
        fi
        success "Installed Grafana ${GRAFANA_VERSION}"
    else
        success "Grafana already installed"
    fi

    if [[ ! -x "$ne_target/node_exporter" ]] || ! "$ne_target/node_exporter" --version 2>&1 | grep -q "version ${NODE_EXPORTER_VERSION}"; then
        _download_if_missing "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/${ne_dir_name}.tar.gz" "$ne_archive"
        rm -rf "$ne_target"
        _extract_dir_if_needed "$ne_archive" "$ne_dir_name" "$ne_target"
        success "Installed Node Exporter ${NODE_EXPORTER_VERSION}"
    else
        success "Node Exporter already installed"
    fi

    _write_monitoring_conf_if_absent

    local prom_port ne_port grafana_port grafana_user grafana_password
    prom_port="$(grep -E '^[[:space:]]*prometheus_port[[:space:]]*=' "$MONITORING_WORKSPACE_DIR/monitoring.conf" | tail -n1 | sed -E 's/^[^=]+=//; s/#.*$//; s/^ *//; s/ *$//')"
    ne_port="$(grep -E '^[[:space:]]*node_exporter_port[[:space:]]*=' "$MONITORING_WORKSPACE_DIR/monitoring.conf" | tail -n1 | sed -E 's/^[^=]+=//; s/#.*$//; s/^ *//; s/ *$//')"
    grafana_port="$(grep -E '^[[:space:]]*grafana_port[[:space:]]*=' "$MONITORING_WORKSPACE_DIR/monitoring.conf" | tail -n1 | sed -E 's/^[^=]+=//; s/#.*$//; s/^ *//; s/ *$//')"
    grafana_user="$(grep -E '^[[:space:]]*grafana_admin_user[[:space:]]*=' "$MONITORING_WORKSPACE_DIR/monitoring.conf" | tail -n1 | sed -E 's/^[^=]+=//; s/#.*$//; s/^ *//; s/ *$//')"
    grafana_password="$(grep -E '^[[:space:]]*grafana_admin_password[[:space:]]*=' "$MONITORING_WORKSPACE_DIR/monitoring.conf" | tail -n1 | sed -E 's/^[^=]+=//; s/#.*$//; s/^ *//; s/ *$//')"

    prom_port="${prom_port:-9090}"
    ne_port="${ne_port:-9100}"
    grafana_port="${grafana_port:-3000}"
    grafana_user="${grafana_user:-admin}"
    grafana_password="${grafana_password:-admin}"

    _render_prometheus_config "$prom_port" "$ne_port"
    _render_grafana_config "$grafana_port" "$prom_port" "$grafana_user" "$grafana_password"
    _install_bundled_dashboards

    _download_dashboard_if_missing \
        "https://grafana.com/api/dashboards/1860/revisions/37/download" \
        "$MONITORING_WORKSPACE_DIR/grafana/provisioning/dashboards/json/node-exporter-full.json" \
        "node-exporter-full" \
        "Node Exporter Full" || warn "Failed to download Node Exporter dashboard; you can import Grafana ID 1860 manually"

    if "$HOME/code/dotfiles/bin/monitoring-add-doris"; then
        success "Doris monitoring configured"
    else
        warn "Doris cluster was not detected; Doris monitoring not added"
        warn "After Doris is ready, run: monitoring-add-doris"
    fi

    "$HOME/code/dotfiles/bin/monitoring-start"

    info "Monitoring stack is ready"
    info "Grafana:    http://127.0.0.1:${grafana_port}"
    info "Prometheus: http://127.0.0.1:${prom_port}"
    info "Node Exporter: http://127.0.0.1:${ne_port}/metrics"
}

if [[ "${BASH_SOURCE[0]:-$0}" == "$0" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
    source "$SCRIPT_DIR/_common.sh"

    install_monitoring
    ensure_bashrc
    hint_source_bashrc
fi
