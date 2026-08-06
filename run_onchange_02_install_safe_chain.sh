#!/bin/bash

set -euo pipefail

safe_chain_version='1.5.15'
safe_chain_installer_sha256='de0565e3d6346407a604e84e639e95fea8758748063da2216bbfdca5feda5dd2'
safe_chain_install_dir="${XDG_DATA_HOME:-$HOME/.local/share}/safe-chain"
safe_chain_installer="$(mktemp "${TMPDIR:-/tmp}/safe-chain-installer.XXXXXX")"
safe_chain_setup_home="$(mktemp -d "${TMPDIR:-/tmp}/safe-chain-setup.XXXXXX")"

cleanup() {
  rm -f -- "$safe_chain_installer"
  rm -rf -- "$safe_chain_setup_home"
}
trap cleanup EXIT

curl -fsSL \
  "https://github.com/AikidoSec/safe-chain/releases/download/${safe_chain_version}/install-safe-chain.sh" \
  -o "$safe_chain_installer"

printf '%s  %s\n' "$safe_chain_installer_sha256" "$safe_chain_installer" | sha256sum -c -

HOME="$safe_chain_setup_home" \
ZDOTDIR="$safe_chain_setup_home" \
XDG_CONFIG_HOME="$safe_chain_setup_home/.config" \
sh "$safe_chain_installer" \
  --install-dir "$safe_chain_install_dir"

if [[ ! -r "$safe_chain_install_dir/scripts/init-posix.sh" ]]; then
  echo 'Safe Chain shell initialization script was not installed.' >&2
  exit 1
fi
