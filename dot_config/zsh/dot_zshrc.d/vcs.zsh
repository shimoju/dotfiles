# git
alias g='git'

# gtr (Git Worktree Runner)
if (( $+commands[git-gtr] )); then
  _gtr_init="${XDG_CACHE_HOME:-$HOME/.cache}/gtr/init-gtr.zsh"
  [[ -f "$_gtr_init" ]] || eval "$(git gtr init zsh)" || true
  source "$_gtr_init" 2>/dev/null || true; unset _gtr_init
fi

# hunk
alias hd='hunk diff --watch'
alias hs='hunk diff --watch --staged'
alias hsh='hunk show'

# gitui
alias gu='gitui'
