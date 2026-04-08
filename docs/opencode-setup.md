# OpenCode Setup

This repository keeps persistent project instructions in `AGENTS.md`.

## Recommended launcher

Use the repo-local wrapper instead of calling `opencode` directly:

```bash
~/code/dotfiles/bin/opencode-project
```

The wrapper:

- starts OpenCode in this repository
- reads `AGENTS.md`
- injects the file content into the startup prompt with `opencode --prompt`

## Why this exists

The local OpenCode CLI in this environment exposes `--prompt`, but this repo does not currently have a built-in project-level auto-load config file.

This wrapper gives you a stable project entrypoint without depending on global machine state.

## Optional shell alias

If you want a shorter command, add an alias in your shell config:

```bash
alias ocp='~/code/dotfiles/bin/opencode-project'
```

## Updating rules

Edit `AGENTS.md` whenever you want to change default project instructions.

Examples of good rules:

- installation constraints
- code review expectations
- commit and push safety rules
- repository-specific coding conventions
