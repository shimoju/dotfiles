# mise
if (( $+commands[mise] )); then
  eval "$(mise activate zsh)"

  _mise_completion_dir="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/site-functions"
  _mise_completion_file="$_mise_completion_dir/_mise"

  if [[ ! -s "$_mise_completion_file" || "$commands[mise]" -nt "$_mise_completion_file" ]]; then
    command mkdir -p "$_mise_completion_dir"
    _mise_completion_tmp="${_mise_completion_file}.$$.tmp"
    if command mise completion zsh >| "$_mise_completion_tmp"; then
      command mv -f -- "$_mise_completion_tmp" "$_mise_completion_file"
    else
      command rm -f -- "$_mise_completion_tmp"
    fi
  fi

  fpath=("$_mise_completion_dir" $fpath)
  unset _mise_completion_dir _mise_completion_file _mise_completion_tmp
fi
