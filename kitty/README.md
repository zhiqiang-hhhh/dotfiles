# kitty

This directory keeps the kitty terminal configuration managed together with `dotfiles`.

## Layout

- `kitty/kitty.conf` is the tracked config file in this repo
- `~/.config/kitty/kitty.conf` should be a symlink to that file

## Why symlink

- Keep kitty using its default config location
- Keep all changes version-controlled from this repository

## Verify

```bash
ls -l ~/.config/kitty/kitty.conf
```

Expected target:

```text
~/code/dotfiles/kitty/kitty.conf
```

## Keybinding convention

- `Cmd + ...` is for tab-level actions
- `Cmd + Alt + ...` is for pane/window-level actions

### Current shortcuts

- Tab: `Cmd+T` new tab, `Cmd+Left/Right` switch tab
- Layout/focus mode: `Cmd+Alt+Enter` toggle stack layout (zoom current pane in tab)
- Pane navigation: `Cmd+Alt+Left/Right/Up/Down` move focus between panes
- Pane close: `Cmd+Alt+Backspace` close current pane
- OS window fullscreen: `Cmd+Enter` toggle fullscreen

## SSH Connection Reuse (ControlMaster)

For remote development, this setup supports creating new kitty panes/windows that reuse an existing SSH session instead of starting a fresh login every time.

### Effect

- New remote panes/windows open faster
- Avoid repeated SSH handshake/authentication for each split
- Keep workflow consistent when splitting from an already connected remote pane

### How it works

- `kitty` enables `allow_remote_control yes` in `kitty/kitty.conf`
- Remote login must be started with `rssh` (not plain `ssh`), so current window can publish reusable SSH command state
- Shortcut mappings call `remote_control_script` with `bin/kitty-remote-fork`
  - `Cmd+Alt+Shift+Enter` -> fork remote shell with vertical split (`vsplit`)
  - `Cmd+Alt+Shift+-` -> fork remote shell with horizontal split (`hsplit`)
  - `Cmd+Alt+Shift+=` -> fork remote shell as a new pane/window (`window`)
- The helper script relies on SSH ControlMaster/ControlPath/ControlPersist behavior, so the new pane can reuse the existing master connection when available

### Requirement

- Use `rssh <host>` (or `rssh <ssh-args> <host>`) in kitty when entering remote sessions you want to fork
- `rssh` wraps `ssh`, records the exact ssh command for the current kitty window, and clears it when the session exits
