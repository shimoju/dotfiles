(( ! $+commands[anyenv] )) && return 1

eval "$(anyenv init -)"
path=($path)

if [[ -x "$HOME/.anyenv/envs/rbenv/bin/rbenv" ]]; then
  fpath=("$HOME/.anyenv/envs/rbenv/completions" $fpath)
fi

if [[ -x "$HOME/.anyenv/envs/nodenv/bin/nodenv" ]]; then
  fpath=("$HOME/.anyenv/envs/nodenv/completions" $fpath)
fi
