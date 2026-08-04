(( ! $+commands[git] )) && return 1

alias g='git'

if (( $+commands[git-gtr] )); then
  _gtr_init="${XDG_CACHE_HOME:-$HOME/.cache}/gtr/init-gtr.zsh"
  [[ -f "$_gtr_init" ]] || eval "$(git gtr init zsh)" || true
  source "$_gtr_init" 2>/dev/null || true; unset _gtr_init
fi
