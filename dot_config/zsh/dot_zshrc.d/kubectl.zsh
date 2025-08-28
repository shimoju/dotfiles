(( ! $+commands[kubectl] )) && return 1

source <(kubectl completion zsh)
alias k='kubectl'
