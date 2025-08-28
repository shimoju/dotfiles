alias vi='vim'
alias v='vim'

(( ! $+commands[nvim] )) && return 1

alias vim='nvim'
export EDITOR='nvim'
export VISUAL='nvim'
