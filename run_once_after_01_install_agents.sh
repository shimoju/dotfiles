#!/bin/bash

set -euo pipefail

# Claude Code
if [[ ! -x "$HOME/.local/bin/claude" ]]; then
  echo 'Install Claude Code:'
  curl -fsSL https://claude.ai/install.sh | bash
fi

# Codex
if [[ ! -x "$HOME/.local/bin/codex" ]]; then
  echo 'Install Codex:'
  curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh
fi

# Chrome DevTools MCP
if [[ -x "$HOME/.local/bin/claude" ]] &&
  ! "$HOME/.local/bin/claude" mcp get chrome-devtools >/dev/null 2>&1; then
  "$HOME/.local/bin/claude" mcp add --transport stdio --scope user chrome-devtools -- \
    "$HOME/.local/bin/mise" -C "$HOME" exec -- chrome-devtools-mcp
fi

if [[ -x "$HOME/.local/bin/codex" ]] &&
  ! "$HOME/.local/bin/codex" mcp get chrome-devtools >/dev/null 2>&1; then
  "$HOME/.local/bin/codex" mcp add chrome-devtools -- \
    "$HOME/.local/bin/mise" -C "$HOME" exec -- chrome-devtools-mcp
fi

# herdr
if command -v herdr >/dev/null; then
  echo 'Install herdr integrations:'
  herdr integration install claude
  herdr integration install codex
fi
