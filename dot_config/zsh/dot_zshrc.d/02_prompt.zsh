# Shsh prompt
_prompt_dir="${ZDOTDIR:-$HOME}/prompt"
fpath=("$_prompt_dir" $fpath)

autoload -Uz promptinit
promptinit
prompt shsh

unset _prompt_dir
