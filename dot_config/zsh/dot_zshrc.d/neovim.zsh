alias v='vim'

if (( $+commands[nvim] )); then
  alias vim='nvim'
  alias v='nvim'
  export EDITOR='nvim'
  export VISUAL='nvim'
fi
