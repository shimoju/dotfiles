# Repository guidance

## Scope

- This repository is the chezmoi source state for personal dotfiles, primarily for macOS with inexpensive Linux compatibility where practical.
- Edit only source-state files in this repository. Do not edit deployed files under `$HOME` or run `chezmoi apply` unless the user explicitly asks.
- Preserve unrelated worktree changes. Do not install packages or update external tools unless requested.

## Repository layout

- Follow chezmoi naming: `dot_*`, `private_*`, `symlink_*`, and `run_once_*` map to target state.
- Keep repository-only files such as `README.md`, `AGENTS.md`, and `CLAUDE.md` in `.chezmoiignore`.
- Manage Homebrew packages in `dot_homebrew/Brewfile` and development runtimes in `dot_config/mise/config.toml`.
- External resources declared in `.chezmoiexternal.toml` are managed by chezmoi; do not edit checked-out copies directly.

## Configuration principles

- Prefer small, explicit configuration over frameworks, generated boilerplate, or speculative features.
- Add aliases and integrations only when they have a concrete use. Keep comments only for non-obvious ordering, portability, or safety constraints.
- Keep generated caches, completion files, secrets, and machine-local state out of version control.

## Zsh responsibilities

- `dot_config/zsh/dot_zshenv`: keep minimal; only settings required by every zsh invocation. Avoid external commands.
- `dot_config/zsh/dot_zprofile`: login-session environment, exported variables, and base `PATH`, including Homebrew.
- `dot_config/zsh/dot_zshrc`: interactive options, history, key bindings, aliases, completion styles, and plugin loading.
- `dot_config/zsh/dot_zshrc.d/*.zsh`: tool-specific activation, aliases, and integration. Fragments load alphabetically; avoid hidden ordering dependencies and document any unavoidable dependency.
- Prefer terminfo for terminal keys. Add literal escape-sequence fallbacks only for observed terminal-mode differences.
- Prefix top-level temporary variables with a descriptive `_` name and `unset` them. Use `local` for variables inside functions.

## Verification

- Run `git diff --check` after edits.
- Run `zsh -n` on every changed zsh file and `bash -n` on changed rendered shell scripts.
- Run `chezmoi diff` to inspect the target-state effect; do not apply it automatically.
- For interactive shell behavior, prefer an isolated `zsh -dfi` test or ask the user to verify after applying and restarting the shell.
- Report the source files changed, checks run, and any required manual `chezmoi apply` or restart step.
