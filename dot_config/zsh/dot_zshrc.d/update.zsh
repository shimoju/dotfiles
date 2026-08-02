update() {
  brew update && brew upgrade --no-ask
  brew cleanup
  anyenv update
  rustup update
  antidote update

  if (( $+commands[claude] )); then
    claude update
  fi

  if (( $+commands[codex] )); then
    curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh
  fi
}
