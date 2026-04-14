# dotfiles

Personal development machine bootstrap and shell configuration.

This repo now also includes kitty terminal config under `kitty/`, so terminal keybindings and related helper scripts are managed in one place.

Inspired by https://github.com/ryanb/dotfiles.

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
- configuring `~/.bashrc` to source `bashrc.d/*.sh`
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
bash ~/code/dotfiles/install/doris-thirdparty.sh
bash ~/code/dotfiles/install/doris-workspace.sh
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

- `monitoring-start` - start all components
- `monitoring-stop` - stop all components
- `monitoring-status` - show component status
- `monitoring-add-doris` - retry Doris monitoring discovery and config update
- `cmonitoring` - `cd ~/workspace/monitoring`

### Doris monitoring behavior

The installer automatically tries to add Doris monitoring by checking the existing Doris workspace and probing:

- FE metrics: `http://127.0.0.1:<fe_http_port>/metrics`
- BE metrics: `http://127.0.0.1:<be_webserver_port>/metrics`

Behavior is idempotent:

- if Doris is not configured, no Doris scrape job is added
- if Doris exists but only FE or BE is reachable, only the reachable target is added
- if Doris starts later, rerun `monitoring-add-doris`
- rerunning the installer is safe and will reconcile the monitoring config

Grafana provisioning includes:

- Node Exporter dashboard: Grafana ID `1860`
- Doris Overview dashboard: bundled custom dashboard source derived from Grafana ID `9734`, automatically adapted to the local Prometheus datasource UID and detected Doris targets when Doris monitoring is configured

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
  - `doris_ports` - wrapper for `bin/doris-ports`
  - `doris_help` - wrapper for `bin/doris-help`
  - `todoris` - wrapper for `bin/todoris`
  - `addbe` / `add_be` - wrapper for `bin/addbe`
  - `restart_fe` - wrapper for `bin/restart-fe`
  - `restart_be` - wrapper for `bin/restart-be`
- Executables in `bin/`:
  - `doris-help` - show Doris shortcut usage
  - `doris-ports` - read and print FE/BE ports from `~/workspace/doris/{fe,be}/conf`
  - `restart-fe` - restart FE (`stop_fe.sh` then `start_fe.sh --daemon` by default)
  - `restart-be` - restart BE (`stop_be.sh` then `start_be.sh --daemon` by default)
  - `todoris` - connect to Doris FE query port with mysql client:
  - `mysql -h 127.0.0.1 -P <query_port_from_fe.conf> -uroot`
  - `addbe [host] [heartbeat_port]` - run `ALTER SYSTEM ADD BACKEND` via FE query port
    - defaults: `host=127.0.0.1`, `heartbeat_port` from `be.conf`
