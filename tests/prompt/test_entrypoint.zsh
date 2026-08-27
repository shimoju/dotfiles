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
typeset _test_zdotdir=$(mktemp -d "${TMPDIR:-/tmp}/prompt-shsh-entrypoint.XXXXXXXX")
export TERM=dumb

cleanup() {
  async_stop_worker _shsh 2>/dev/null || true
  async_stop_worker _shsh_fetch 2>/dev/null || true
  rm -rf -- "$_test_zdotdir"
}
trap cleanup EXIT

ln -s "${_source_zdotdir}/prompt" "${_test_zdotdir}/prompt"

source "$ASYNC_ZSH_PATH"
ZDOTDIR=$_test_zdotdir
setopt promptsubst
typeset -gi _previous_winch_calls=0 _previous_winch_signal=0
TRAPWINCH() {
  (( ++_previous_winch_calls ))
  _previous_winch_signal=$1
}
source "${_source_zdotdir}/dot_zshrc" > "${_test_zdotdir}/startup-output"

assert 'theme setup does not print a blank line' \
  test ! -s "${_test_zdotdir}/startup-output"
assert 'theme enables prompt substitution for width-aware rendering' \
  test "${options[promptsubst]}" = on
assert 'precmd hook is registered' \
  test "${precmd_functions[(Ie)_shsh_precmd]}" -gt 0
assert 'preexec hook is registered' \
  test "${preexec_functions[(Ie)_shsh_preexec]}" -gt 0
assert 'prompt contains only the fixed renderer call' \
  test "$PROMPT" = '$(_shsh_expand_prompt)'
typeset _expanded_prompt=$(_shsh_expand_prompt)
assert 'expanded prompt has two lines' \
  test "${#${(f)_expanded_prompt}}" -eq 2
assert 'input line contains only the prompt symbol' \
  test "${${(f)_expanded_prompt}[2]}" = '%F{#a6e3a1}❯%f '
assert 'right prompt is unused' \
  test -z "$RPROMPT"
assert 'theme directory is first in fpath' \
  test "$fpath[1]" = "${_test_zdotdir}/prompt"
typeset -i _winch_signal=$(( signals[(i)WINCH] - 1 ))
TRAPWINCH $_winch_signal
assert 'existing function-based WINCH trap is untouched' \
  test "$_previous_winch_calls" -eq 1
assert 'WINCH trap receives the signal number' \
  test "$_previous_winch_signal" -eq "$_winch_signal"

(( _failures == 0 ))
