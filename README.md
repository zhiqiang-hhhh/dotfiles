# dotfiles

Personal development machine bootstrap and shell configuration.

This repo now also includes terminal config under `kitty/` and `iterm2/`, so terminal keybindings and related helper scripts are managed in one place.

Inspired by https://github.com/ryanb/dotfiles.

Run `dothelp` for an overview of every command this repo adds (ClickHouse,
ZooKeeper, MinIO, monitoring, Doris).

## OpenCode project rules

- Persistent project instructions live in `AGENTS.md`.
- Start OpenCode for this repo with `bin/opencode-project` to inject those rules automatically.
- Setup details are documented in `docs/opencode-setup.md`.

## Platform support

- Linux: fully supported.
- macOS: supported for bootstrap, shell/git/ssh setup, and most optional tool installers.
- `install/ldb_toolchain.sh` is Linux-focused and will be skipped on macOS.

## Kitty config (new)

- Tracked kitty config lives at `kitty/kitty.conf`
- Expected live path is `~/.config/kitty/kitty.conf` (symlink)
- Some mappings call `bin/kitty-remote-fork` in this repo for pane split/fork behavior
- Set or repair the symlink with: `bash ~/code/dotfiles/install/kitty.sh`

## iTerm2 config

- Tracked iTerm2 settings live at `iterm2/settings/com.googlecode.iterm2.plist`
- iTerm2 is configured to load settings from the custom folder `iterm2/settings`
- GUI changes are written back to the repo folder when iTerm2 quits if `Save changes to folder when iTerm2 quits` is enabled
- Set or repair the custom settings folder with: `bash ~/code/dotfiles/install/iterm2.sh`

iTerm2 also supports loading settings from a URL, but using the local repo path is better for dotfiles because it works offline and GUI changes can be committed normally after iTerm2 writes them back to the settings folder.

## Vim config

- Tracked vimrc lives at `vim/vimrc`, symlinked to `~/.vimrc`
- Link or repair it with: `bash ~/code/dotfiles/install/vim.sh`
- XML editing: open a `.xml` file and run `gg=G` (whole file) or `<leader>x` to
  reformat. Formatting is done by `bin/xmlfmt` (`xmllint --format`, 4-space
  indent, no injected `<?xml?>` line); `%` jumps between matching tags.

## Quick Start (run via curl)

You can run the bootstrap script directly from GitHub:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/zhiqiang-hhhh/dotfiles/main/bootstrap.sh)
```

This script will guide you through:

- creating standard directories (`~/code`, `~/workspace`, `~/tools`, `~/bin`, `~/downloads`)
- using git when available, otherwise downloading the dotfiles archive directly
- setting up SSH key and git config
- cloning this repo to `~/code/dotfiles`
- configuring shell PATH (`~/.zshrc` for zsh, `~/.bashrc` for bash helpers)
- optional tool installation (JDK, Maven, ldb_toolchain, Go, anaconda/conda, rclone, GitHub CLI, ripgrep)
- optional monitoring stack installation (Prometheus, Grafana, Node Exporter)
- cloning repos from `repos.conf`
- optional Doris thirdparty setup
- optional Doris workspace runtime setup (`~/workspace/doris`)

## Safer alternative (download then inspect)

If you prefer not to execute remote content directly, download first:

```bash
curl -fsSL -o /tmp/bootstrap.sh https://raw.githubusercontent.com/zhiqiang-hhhh/dotfiles/main/bootstrap.sh
bash /tmp/bootstrap.sh
```

## Re-run individual installers

After bootstrap, you can run installers independently:

```bash
bash ~/code/dotfiles/install/java.sh
bash ~/code/dotfiles/install/maven.sh
bash ~/code/dotfiles/install/ldb_toolchain.sh
bash ~/code/dotfiles/install/go.sh
bash ~/code/dotfiles/install/anaconda.sh
bash ~/code/dotfiles/install/rclone.sh
bash ~/code/dotfiles/install/gh.sh
bash ~/code/dotfiles/install/ripgrep.sh
bash ~/code/dotfiles/install/monitoring.sh
bash ~/code/dotfiles/install/kitty.sh
bash ~/code/dotfiles/install/iterm2.sh
bash ~/code/dotfiles/install/doris-thirdparty.sh
bash ~/code/dotfiles/install/doris-workspace.sh
bash ~/code/dotfiles/install/clickhouse-workspace.sh
```

## Monitoring stack

This repo includes a local binary-based monitoring stack installer for:

- Prometheus
- Grafana OSS
- Node Exporter

Install it with:

```bash
bash ~/code/dotfiles/install/monitoring.sh
```

Installed layout:

- binaries: `~/tools/monitoring/{prometheus,grafana,node_exporter}`
- runtime data and config: `~/workspace/monitoring`
- user config: `~/workspace/monitoring/monitoring.conf`

Default ports:

- Grafana: `3000`
- Prometheus: `9090`
- Node Exporter: `9100`

You can change ports in `~/workspace/monitoring/monitoring.conf` and rerun the installer.

### Monitoring commands

- `start-monitoring` - start all components
- `stop-monitoring` - stop all components
- `status-monitoring` - show component status
- `add-doris-monitoring` - retry Doris monitoring discovery and config update
- `add-clickhouse-monitoring` - retry ClickHouse Grafana datasource and dashboard provisioning
- `add-clickhouse-s3-monitoring` - provision the ClickHouse S3 disk (MinIO) dashboard
- `cmonitoring` - `cd ~/workspace/monitoring`

### Doris monitoring behavior

The installer automatically tries to add Doris monitoring by checking the existing Doris workspace and probing:

- FE metrics: `http://127.0.0.1:<fe_http_port>/metrics`
- BE metrics: `http://127.0.0.1:<be_webserver_port>/metrics`

Behavior is idempotent:

- if Doris is not configured, no Doris scrape job is added
- if Doris exists but only FE or BE is reachable, only the reachable target is added
- if Doris starts later, rerun `add-doris-monitoring`
- rerunning the installer is safe and will reconcile the monitoring config

Grafana provisioning includes:

- Node Exporter dashboard: Grafana ID `1860`
- Doris Overview dashboard: bundled custom dashboard source derived from Grafana ID `9734`, automatically adapted to the local Prometheus datasource UID and detected Doris targets when Doris monitoring is configured
- ClickHouse datasource: `grafana-clickhouse-datasource`, pointed at the detected local ClickHouse HTTP port
- ClickHouse Local Overview dashboard: direct queries against `system.*` tables through the ClickHouse Grafana datasource

### ClickHouse monitoring behavior

The installer automatically tries to add ClickHouse monitoring by checking:

- `~/workspace/clickhouse/conf/node1.xml`
- `~/workspace/clickhouse/conf/config.xml`
- `~/workspace/clickhouse/conf/node2.xml`

It reads the first available `http_port`, prefers a node that answers `/ping`,
and provisions Grafana to query ClickHouse directly. It does not edit ClickHouse
configs or require Prometheus metrics to be enabled in ClickHouse.

Useful overrides:

- `CLICKHOUSE_WORKSPACE=/path/to/clickhouse-workspace`
- `CLICKHOUSE_GRAFANA_USER=default`
- `CLICKHOUSE_GRAFANA_PASSWORD=...`
- `CLICKHOUSE_GRAFANA_DATABASE=default`

If ClickHouse starts later, rerun:

```bash
add-clickhouse-monitoring
stop-monitoring grafana && start-monitoring grafana
```

## Doris workspace runtime layout

For shared development machines, keep machine-local Doris configs in `~/workspace`
and link key runtime paths to `~/code/doris/output`:

- `~/workspace/doris/fe/bin` -> `~/code/doris/output/fe/bin`
- `~/workspace/doris/fe/lib` -> `~/code/doris/output/fe/lib`
- `~/workspace/doris/be/bin` -> `~/code/doris/output/be/bin`
- `~/workspace/doris/be/lib` -> `~/code/doris/output/be/lib`
- `~/workspace/doris/fe/doris-meta` is initialized from `~/code/doris/output/fe/doris-meta` if absent
- `~/workspace/doris/be/conf/be.conf` is updated to use:
  - `storage_root_path = ~/workspace/doris/be/storage`
  - `tmp_file_dirs = ~/workspace/doris/be/storage/tmp`

This way, after rebuilding Doris, restarting the cluster picks up new binaries,
while local `fe/be` configs (such as ports) stay in workspace.

## Doris shell shortcuts

After reloading shell, these helpers are available:

- Shell functions in `bashrc.d/40-doris.sh`:
  - `cdoris` - `cd ~/workspace/doris`
  - `cfe` - `cd ~/workspace/doris/fe`
  - `cbe` - `cd ~/workspace/doris/be`
  - `tobe` - alias behavior, also `cd ~/workspace/doris/be`
  - `ports_doris` - wrapper for `bin/ports-doris`
  - `help_doris` - wrapper for `bin/help-doris`
  - `client_doris` - wrapper for `bin/client-doris`
  - `add_be` - wrapper for `bin/add-be`
  - `restart_fe` - wrapper for `bin/restart-fe`
  - `restart_be` - wrapper for `bin/restart-be`
  - `rebuild_doris` - wrapper for `bin/rebuild-doris`
- Executables in `bin/`:
  - `help-doris` - show Doris shortcut usage
  - `ports-doris` - read and print FE/BE ports from `~/workspace/doris/{fe,be}/conf`
  - `restart-fe` - restart FE (`stop_fe.sh` then `start_fe.sh --daemon` by default)
  - `restart-be` - restart BE (`stop_be.sh` then `start_be.sh --daemon` by default)
  - `client-doris` - connect to Doris FE query port with mysql client:
  - `mysql -h 127.0.0.1 -P <query_port_from_fe.conf> -uroot`
  - `add-be [host] [heartbeat_port]` - run `ALTER SYSTEM ADD BACKEND` via FE query port
    - defaults: `host=127.0.0.1`, `heartbeat_port` from `be.conf`

## ClickHouse workspace runtime layout

The ClickHouse helper scripts expect local runtime files under:

- `~/workspace/clickhouse`
- `~/workspace/zookeeper/apache-zookeeper-*-bin`

The deployment script prepares missing runtime directories and links:

- `~/workspace/clickhouse/bin/clickhouse` -> `~/code/ClickHouse/build/programs/clickhouse`

It does not overwrite existing ClickHouse configs or data. Existing configs are
expected under:

- `~/workspace/clickhouse/conf/config.xml` - single-node config
- `~/workspace/clickhouse/conf/node1.xml` - local cluster node 1
- `~/workspace/clickhouse/conf/node2.xml` - local cluster node 2
- `~/workspace/clickhouse/conf/users.xml`

Run or refresh the workspace:

```bash
bash ~/code/dotfiles/install/clickhouse-workspace.sh
```

Useful environment overrides:

- `CLICKHOUSE_WORKSPACE=/path/to/workspace`
- `CLICKHOUSE_BINARY=/path/to/clickhouse`
- `CLICKHOUSE_BUILD_DIR=/path/to/ClickHouse/build`
- `ZOOKEEPER_HOME=/path/to/apache-zookeeper-*-bin`

## ClickHouse and ZooKeeper shortcuts

After reloading shell, these helpers are available:

- Shell functions in `bashrc.d/50-clickhouse.sh`:
  - `cch` - `cd ~/workspace/clickhouse`
  - `czk` - `cd ~/workspace/zookeeper`
  - `deploy_ch` - wrapper for `bin/deploy-ch`
  - `start_ch` / `stop_ch` / `restart_ch` / `status_ch`
  - `start_zk` / `stop_zk` / `restart_zk` / `status_zk`
  - `client_ch` - connect with `clickhouse client`
  - `help_ch` - show ClickHouse shortcut usage
- Executables in `bin/`:
  - `deploy-ch` - prepare workspace and binary symlink
  - `start-ch [all|node1|node2|single]`
  - `stop-ch [--force] [all|node1|node2|single]`
  - `restart-ch [all|node1|node2|single]`
  - `status-ch [all|node1|node2|single]`
  - `client-ch [node1|node2|single] [clickhouse-client args...]`
  - `help-ch`
  - `start-zk`, `stop-zk`, `restart-zk`, `status-zk`

When `node1.xml` or `node2.xml` exists, `start-ch` defaults to `all`.
Use `start-ch single` to start `conf/config.xml`.

## Local MinIO as a ClickHouse S3 disk

Run a local MinIO instance and use it as the object-storage target for a
ClickHouse `s3` disk, fronted by a local filesystem cache (10Gi by default).
Uses official MinIO binaries — no brew, no sudo, no system package manager.

### Install and run MinIO

```bash
bash ~/code/dotfiles/install/minio.sh   # or: deploy-minio
start-minio
status-minio
```

Layout:

- binaries: `~/tools/minio/{minio,mc}`
- data: `~/workspace/minio/data`
- config: `~/workspace/minio/minio.conf`
- mc client config dir: `~/workspace/minio/mc` (never touches `~/.mc`)

Defaults (edit `~/workspace/minio/minio.conf`, then `restart-minio`):

- S3 API port `19900`, Console port `19901` (chosen to avoid the local
  ClickHouse ports `19001/19002/...`)
- root user / password `minioadmin` / `minioadmin`
- bucket `clickhouse` (created automatically on first start)

MinIO commands (shell functions in `bashrc.d/46-minio.sh`, executables in `bin/`):

- `deploy-minio` - download binaries and write config
- `start-minio` / `stop-minio` / `restart-minio` / `status-minio`
- `cminio` - `cd ~/workspace/minio`

### Wire ClickHouse to MinIO

```bash
configure-ch-s3-minio all      # or: single | node1 | node2
restart-ch all
```

`configure-ch-s3-minio` reads the MinIO endpoint, bucket, and credentials from
`~/workspace/minio/minio.conf` and **replaces** the `<storage_configuration>`
block in each selected ClickHouse config (backing the file up first as
`*.bak.<timestamp>`). It provisions, per node:

- disk `minio_s3` (`type=s3`) pointed at `s3://<bucket>/<node>/` so nodes never
  collide on the same prefix
- disk `minio_s3_cache` (`type=cache`, `max_size=10Gi`) under the node's
  `storage/<node>/disks/minio_s3_cache/`
- storage policy `minio_s3_cache_policy`
- the `default` disk/policy are regenerated so local tables keep working

Override the cache size with `CH_S3_CACHE_SIZE=20Gi configure-ch-s3-minio all`.

Create a table on MinIO-backed storage:

```sql
CREATE TABLE t (id UInt64) ENGINE = MergeTree ORDER BY id
SETTINGS storage_policy = 'minio_s3_cache_policy';
```

### S3 disk dashboard

```bash
add-clickhouse-monitoring        # one-time: datasource + base dashboard
add-clickhouse-s3-monitoring     # S3 disk dashboard
stop-monitoring grafana && start-monitoring grafana
```

`add-clickhouse-s3-monitoring` provisions **two** dashboards (both query
`system.*` directly through the ClickHouse Grafana datasource, no Prometheus):

- **ClickHouse S3 Disk (MinIO)** (`/d/clickhouse-s3-disk`) — storage view: cache
  usage/capacity, MinIO disks, S3/cache event counters, filesystem-cache
  metrics, tables on the MinIO policy, active parts per MinIO disk.
- **ClickHouse S3 & Query Performance** (`/d/clickhouse-s3-perf`) — performance
  view, time-series over the dashboard's time range:
  1. running queries/inserts (now + trend)
  2. completed selects/inserts per interval and over the window
  3. SELECT/INSERT duration `avg / p50 / p90 / p99` (true per-query quantiles
     from `system.query_log`)
  4. S3 requests in-flight, read/write request rate, avg latency, and
     `p50/p90/p99` of per-second average latency
  5. S3 average read/write request size

Data sources and one caveat on the percentiles:

- Rates, gauges, averages and sizes come from `system.metric_log` (collected
  every 1s; `ProfileEvent_*` columns are per-second deltas, so `sum()` = window
  total and `avg()` = per-second rate).
- Query/insert **duration** percentiles are true per-query quantiles from
  `system.query_log`.
- ClickHouse exposes no per-S3-request latency on this version (no
  `blob_storage_log`/`latency_log`), so the S3 latency `p50/p90/p99` panels show
  quantiles of the **per-second average** latency, not per-request tail latency.
  S3 read/write are split by request **rate** (`S3ReadRequestsCount` vs
  `S3WriteRequestsCount`); the in-flight gauge (`S3Requests`) is not split.
