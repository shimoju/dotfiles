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

alias l='ls'
alias la='ls -A'
alias ll='ls -lhA'

export GREP_COLOR='1;30;43'
export GREP_COLORS="mt=$GREP_COLOR"
alias grep='grep --color=auto'
alias diff='diff --color=auto'
