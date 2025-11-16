#!/bin/bash

set -e

if [[ -d "$HOME/.anyenv/envs/rbenv" ]]; then
  ln -sf "$HOME/.config/rbenv-default-gems" "$HOME/.anyenv/envs/rbenv/default-gems"
fi
