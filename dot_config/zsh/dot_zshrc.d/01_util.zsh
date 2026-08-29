update() {
  brew update && brew upgrade --no-ask
  brew cleanup

  if (( $+commands[mise] )); then
    mise self-update -y
    if mise -C "$HOME" upgrade; then
      if [[ "$OSTYPE" == darwin* ]] && (( $+commands[hister-service] )); then
        hister-service restart-if-loaded
      fi
    fi
  fi

  antidote update

  if (( $+commands[claude] )); then
    claude update
  fi

  if (( $+commands[codex] )); then
    codex update
  fi
}
