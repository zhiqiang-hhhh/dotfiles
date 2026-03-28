# Kitty Remote Fork

This setup keeps normal kitty window creation local, while adding a second set of shortcuts that "fork" the current remote SSH target into a new kitty window, split, or tab.

## How It Works

- `rssh` wraps `ssh`
- When run inside kitty, `rssh` records the exact SSH command for the current `KITTY_WINDOW_ID`
- `kitty-remote-fork` looks up the focused kitty window ID and re-runs that recorded SSH command
- OpenSSH `ControlMaster` then reuses the existing SSH connection

## Requirements

- `kitty`
- `kitten` available in `PATH`
- `jq`
- `zsh`
- OpenSSH with `ControlMaster` enabled

## Usage

Use `rssh` instead of `ssh`:

```bash
rssh byte-dev
```

From that kitty window:

- Normal local window: keep using your existing `new_window` shortcut
- Remote fork window: use the custom kitty shortcut wired to `kitty-remote-fork window`
- Remote fork split: use the custom kitty shortcut wired to `kitty-remote-fork vsplit` or `hsplit`

If the focused window was not opened with `rssh`, `kitty-remote-fork` falls back to opening a normal local shell window or split.

## Platform Notes

- The scripts are cross-platform across macOS and Linux as long as `kitten` is discoverable via `PATH`
- If `kitten` is installed in a non-standard location, set `KITTEN_BIN` explicitly

Example:

```bash
export KITTEN_BIN=/custom/path/to/kitten
```

## Files

- `bin/rssh`
- `bin/kitty-remote-fork`
- `docs/kitty-remote-fork.md`
