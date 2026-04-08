# Project Agent Rules

These rules are intended to be loaded into OpenCode at session start for this repository.

## Workflow
- Read the repository state before making assumptions.
- Prefer the smallest correct change.
- Do not revert unrelated user changes.
- Keep changes consistent with the existing shell-script-heavy style of this repo.

## Installation
- Never use system package managers such as `apt`, `apt-get`, `yum`, `dnf`, or `brew`.
- Never require `sudo`.
- Prefer user-space installs under `~/tools` or another user-writable directory.
- Prefer official binaries, tarballs, or zip archives.
- If source build is the only practical option, explain the required user-space build dependencies instead of falling back to package managers.

## Shell Scripts
- Use Bash.
- Keep scripts portable across Linux and macOS when practical.
- Prefer explicit checks and clear failure messages over implicit assumptions.

## Git Safety
- Do not create commits unless explicitly requested.
- Do not amend commits unless explicitly requested.
- Do not push unless explicitly requested.

## Validation
- Run targeted syntax checks for modified shell scripts when possible.
- Mention any unverified areas clearly.
