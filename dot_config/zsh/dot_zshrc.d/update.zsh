update() {
  brew update && brew upgrade --no-ask
  brew cleanup

  if (( $+commands[mise] )); then
    mise self-update
    mise -C "$HOME" upgrade
  fi

  rustup update
  antidote update

  if (( $+commands[claude] )); then
    claude update
  fi

  if (( $+commands[codex] )); then
    curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh
  fi
}
