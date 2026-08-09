(( ! $+commands[fzf] )) && return 1

source <(fzf --zsh)

bindkey -M emacs $'\x1e' fzf-cd-widget

f() {
  local dir
  dir="$(ghq list --full-path | fzf --height "${FZF_TMUX_HEIGHT:-40%}" --min-height 20+ --bind=ctrl-z:ignore --reverse)" || return
  [[ -n "$dir" ]] || return
  builtin cd -- "$dir"
}

_ghq_fzf_cd_widget() {
  f
  zle reset-prompt
}
zle -N _ghq_fzf_cd_widget
bindkey -M emacs '^O' _ghq_fzf_cd_widget
