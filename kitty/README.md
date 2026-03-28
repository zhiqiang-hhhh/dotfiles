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
