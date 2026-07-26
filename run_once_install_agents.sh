#!/bin/bash

set -e

# Claude Code
if ! command -v claude >/dev/null; then
  echo 'Install Claude Code:'
  curl -fsSL https://claude.ai/install.sh | bash
fi

# Codex
if ! command -v codex >/dev/null; then
  echo 'Install Codex:'
  curl -fsSL https://chatgpt.com/codex/install.sh | sh
fi

# herdr
if command -v herdr >/dev/null; then
  echo 'Install herdr integration:'
  herdr integration install claude
  herdr integration install codex
fi
