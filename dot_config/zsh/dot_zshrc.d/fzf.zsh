(( ! $+commands[fzf] )) && return 1

source <(fzf --zsh)
alias f='fzf'
alias fgh='cd "$(ghq list --full-path | fzf)"'
