#!/bin/bash

set -euo pipefail

if [[ -d "$HOME/.anyenv/envs/rbenv" ]]; then
  ln -sfn "$HOME/.config/rbenv-default-gems" "$HOME/.anyenv/envs/rbenv/default-gems"
fi
