alias vi='vim'
alias v='vim'

if (( $+commands[nvim] )); then
  alias vim='nvim'
  export EDITOR='nvim'
  export VISUAL='nvim'
fi
