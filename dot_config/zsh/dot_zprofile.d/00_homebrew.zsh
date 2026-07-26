if [[ -x "/opt/homebrew/bin/brew" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
  export PATH="$(brew --prefix rustup)/bin:$PATH"
fi
