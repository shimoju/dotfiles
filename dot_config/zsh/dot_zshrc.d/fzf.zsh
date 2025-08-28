(( ! $+commands[fzf] )) && return 1

source <(fzf --zsh)
alias f='cd "$(ghq list --full-path | fzf --reverse)"'
