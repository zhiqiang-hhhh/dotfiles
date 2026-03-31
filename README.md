# dotfiles

Personal development machine bootstrap and shell configuration.

This repo now also includes kitty terminal config under `kitty/`, so terminal keybindings and related helper scripts are managed in one place.

Inspired by https://github.com/ryanb/dotfiles.

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
- installing git if needed
- setting up SSH key and git config
- cloning this repo to `~/code/dotfiles`
- configuring `~/.bashrc` to source `bashrc.d/*.sh`
- optional tool installation (JDK, Maven, ldb_toolchain, Go, anaconda/conda, rclone, GitHub CLI)
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
bash ~/code/dotfiles/install/kitty.sh
bash ~/code/dotfiles/install/doris-thirdparty.sh
bash ~/code/dotfiles/install/doris-workspace.sh
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
