(( ! $+commands[fzf] )) && return 1

source <(fzf --zsh)

f() {
  local dir
  dir="$(ghq list --full-path | fzf --reverse)" || return
  [[ -n "$dir" ]] || return
  builtin cd -- "$dir"
}

_ghq_fzf_cd_widget() {
  f
  zle reset-prompt
}
zle -N _ghq_fzf_cd_widget
bindkey -M emacs '^O' _ghq_fzf_cd_widget
