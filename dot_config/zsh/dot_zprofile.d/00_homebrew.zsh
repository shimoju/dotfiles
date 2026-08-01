if [[ -x "/opt/homebrew/bin/brew" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
  path=(/opt/homebrew/opt/rustup/bin(N) $path)
fi
