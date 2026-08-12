# herdr
alias h='herdr'

_herdr_widget() {
  zle .push-line
  BUFFER=' herdr'
  zle .accept-line
}
zle -N _herdr_widget
bindkey -M emacs '^S' _herdr_widget
