if [[ -x "/opt/homebrew/bin/brew" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
  path=("$(brew --prefix rustup)/bin" $path)
fi
