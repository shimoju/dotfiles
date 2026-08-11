# Builtin commands
_ls_version="$(command ls --version 2>&1)"
if [[ ${(@M)${(f)_ls_version}:#*(GNU|lsd|uutils) *} ]]; then
  export LS_COLORS=${LS_COLORS:-'di=34:ln=35:so=32:pi=33:ex=31:bd=36;01:cd=33;01:su=31;40;07:sg=36;40;07:tw=32;40;07:ow=33;40;07:'}
  alias ls='ls --color=auto'
else
  export LSCOLORS=${LSCOLORS:-'exfxcxdxbxGxDxabagacad'}
  alias ls='ls -G'
fi
unset _ls_version

export GREP_COLOR='1;30;43'
export GREP_COLORS="mt=$GREP_COLOR"
alias grep='grep --color=auto'
alias diff='diff --color=auto'

# eza
if (( $+commands[eza] )); then
  alias l='eza --icons=auto'
  alias la='eza -A --icons=auto'
  alias ll='eza -lA --icons=auto'
else
  alias l='ls'
  alias la='ls -A'
  alias ll='ls -lhA'
fi

# zoxide
if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh)"
fi

# fzf
if (( $+commands[fzf] )); then
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
fi

# yazi
function y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  command yazi "$@" --cwd-file="$tmp"
  IFS= read -r -d '' cwd < "$tmp"
  [ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
  command rm -f -- "$tmp"
}

# safe-chain
if [[ -r "${XDG_DATA_HOME:-$HOME/.local/share}/safe-chain/scripts/init-posix.sh" ]]; then
  source "${XDG_DATA_HOME:-$HOME/.local/share}/safe-chain/scripts/init-posix.sh"
fi
