#!/usr/bin/env zsh

emulate -R zsh
setopt pipefail

typeset -i _failures=0

assert() {
  local description=$1
  shift

  if "$@"; then
    print -r -- "ok - ${description}"
  else
    print -u2 -r -- "not ok - ${description}"
    (( _failures++ ))
  fi
}

typeset _repo_root=${0:A:h:h:h}
typeset _source_zdotdir="${_repo_root}/dot_config/zsh"

source "$ASYNC_ZSH_PATH"
ZDOTDIR=$_source_zdotdir
source "${_source_zdotdir}/dot_zshrc.d/02_prompt.zsh"

assert 'precmd hook is registered' \
  test "${precmd_functions[(Ie)_shsh_precmd]}" -gt 0
assert 'preexec hook is registered' \
  test "${preexec_functions[(Ie)_shsh_preexec]}" -gt 0
assert 'prompt has two lines' \
  test "${#${(f)PROMPT}}" -eq 2
assert 'input line contains only the prompt symbol' \
  test "${${(f)PROMPT}[2]}" = '%F{#a6e3a1}❯%f '
assert 'right prompt is unused' \
  test -z "$RPROMPT"
assert 'theme directory is first in fpath' \
  test "$fpath[1]" = "${_source_zdotdir}/prompt"

async_stop_worker _shsh 2>/dev/null || true
(( _failures == 0 ))
