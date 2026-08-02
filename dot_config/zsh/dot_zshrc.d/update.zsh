update() {
  brew update && brew upgrade --no-ask
  brew cleanup

  if (( $+commands[mise] )); then
    mise self-update
    mise -C "$HOME" upgrade
  fi

  antidote update

  if (( $+commands[claude] )); then
    claude update
  fi

  if (( $+commands[codex] )); then
    codex update
  fi
}
