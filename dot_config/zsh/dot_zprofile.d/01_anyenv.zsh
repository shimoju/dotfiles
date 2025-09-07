if [[ -x "$HOME/.anyenv/bin/anyenv" ]]; then
  export PATH="$HOME/.anyenv/bin:$PATH"
  eval "$(anyenv init -)"
fi

if [[ -x "$HOME/.anyenv/envs/rbenv/bin/rbenv" ]]; then
  FPATH="$HOME/.anyenv/envs/rbenv/completions:$FPATH"
fi

if [[ -x "$HOME/.anyenv/envs/nodenv/bin/nodenv" ]]; then
  FPATH="$HOME/.anyenv/envs/nodenv/completions:$FPATH"
fi
