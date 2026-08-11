if (( $+commands[nvim] )); then
  alias vim='nvim'
  alias v='nvim'
  export EDITOR='nvim'
  export VISUAL='nvim'
else
  alias v='vim'
fi
