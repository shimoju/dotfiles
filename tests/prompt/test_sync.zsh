#!/usr/bin/env zsh

emulate -R zsh
setopt errexit nounset pipefail

typeset -gi _test_count=0

assert_equal() {
  local expected=$1 actual=$2 message=$3
  (( ++_test_count ))
  if [[ $actual != $expected ]]; then
    print -u2 -r -- "not ok ${_test_count} - ${message}"
    print -u2 -r -- "  expected: ${(qqq)expected}"
    print -u2 -r -- "  actual:   ${(qqq)actual}"
    return 1
  fi
  print -r -- "ok ${_test_count} - ${message}"
}

assert_true() {
  local expression=$1 message=$2
  (( ++_test_count ))
  if ! eval "$expression"; then
    print -u2 -r -- "not ok ${_test_count} - ${message}"
    return 1
  fi
  print -r -- "ok ${_test_count} - ${message}"
}

assert_contains() {
  local haystack=$1 needle=$2 message=$3
  (( ++_test_count ))
  if [[ $haystack != *$needle* ]]; then
    print -u2 -r -- "not ok ${_test_count} - ${message}"
    print -u2 -r -- "  missing: ${(qqq)needle}"
    return 1
  fi
  print -r -- "ok ${_test_count} - ${message}"
}

typeset _repo_root=${0:A:h:h:h}
fpath=("${_repo_root}/dot_config/zsh/prompt" $fpath)
autoload -Uz promptinit
promptinit
prompt shsh

_shsh_human_time 5
assert_equal 5s "$REPLY" 'formats seconds'
_shsh_human_time 3665
assert_equal '1h 1m 5s' "$REPLY" 'formats compound duration'
_shsh_human_time 90000
assert_equal '1d 1h' "$REPLY" 'omits zero duration units'

_shsh_shorten_path '~/src/project' 20
assert_equal '~/src/project' "$REPLY" 'keeps a path that fits'
_shsh_shorten_path '~/one/two/three/project' 15
assert_equal '…/three/project' "$REPLY" 'shortens at component boundaries'
_shsh_shorten_path '/a/very-long-component' 8
assert_equal '…mponent' "$REPLY" 'falls back to tail truncation'
_shsh_shorten_path '~/tmp/ドキュメント/プロジェクト' 30
assert_true '(( ${(m)#REPLY} <= 30 ))' \
  'shortens a multibyte path to its display-column limit'
_shsh_shorten_path '~/tmp/ドキュメントドキュメントドキュメント' 20
assert_true '[[ $REPLY == …* ]] && (( ${(m)#REPLY} <= 20 ))' \
  'tail-truncates a long multibyte component without crashing'

_shsh_last_status=0
_shsh_time=12:34:56
COLUMNS=80
_shsh_render
assert_contains "$_shsh_rendered_prompt" $'\n%F{#a6e3a1}❯%f ' 'renders a two-line success prompt'
assert_contains "$_shsh_rendered_prompt" '%F{#89b4fa}' 'renders the path in Mocha Blue'
assert_contains "$_shsh_rendered_prompt" '%F{#7f849c}' 'renders the clock in Mocha Overlay 1'
assert_equal 12:34:56 "$_shsh_render_right_plain" 'keeps the precmd time at the right'
assert_true \
  '(( ${(m)#_shsh_render_left_plain} + _shsh_render_padding + ${(m)#_shsh_render_right_plain} == COLUMNS ))' \
  'aligns the right segment to the terminal edge'

_shsh_git_plain='機能/修正*'
_shsh_git_prompt='%F{#cba6f7}機能/修正%f%F{#fab387}*%f'
_shsh_render
assert_true \
  '(( ${(m)#_shsh_render_left_plain} + _shsh_render_padding + ${(m)#_shsh_render_right_plain} == COLUMNS ))' \
  'aligns multibyte prompt segments by display width'

_shsh_prompt_injection() {
  print -nr -- EXECUTED
}
_shsh_git_plain='$(_shsh_prompt_injection)'
_shsh_git_prompt='%F{#cba6f7}$(_shsh_prompt_injection)%f'
typeset _injection_prompt=$(print -P -r -- "$PROMPT")
assert_contains "$_injection_prompt" '$(_shsh_prompt_injection)' \
  'does not recursively evaluate cached prompt data'
assert_true '[[ $_injection_prompt != *EXECUTED* ]]' \
  'keeps command-like branch text inert under prompt substitution'
unfunction _shsh_prompt_injection
_shsh_git_plain=
_shsh_git_prompt=

_shsh_last_status=1
_shsh_render
assert_contains "$_shsh_rendered_prompt" '%F{#f38ba8}❯%f ' 'renders failures in Mocha Red'

_shsh_command_duration='1m 2s'
COLUMNS=80
_shsh_render
assert_contains "$_shsh_rendered_prompt" '%F{#f9e2af}1m 2s%f' 'renders slow commands in Mocha Yellow'

COLUMNS=20
_shsh_render
assert_true \
  '(( ${(m)#_shsh_render_left_plain} + ${(m)#_shsh_render_right_plain} <= COLUMNS ))' \
  'drops low-priority right content in narrow terminals'

functions[_test_shsh_async_refresh]=$functions[_shsh_async_refresh]
_shsh_async_refresh() { :; }
typeset _precmd_output=$(setopt noerrexit; TERM=dumb; false; _shsh_precmd; print -n -- "marker:${_shsh_last_status}")
assert_equal $'\nmarker:1' "$_precmd_output" 'prints one blank line without losing command status'
functions[_shsh_async_refresh]=$functions[_test_shsh_async_refresh]
unfunction _test_shsh_async_refresh

typeset _redraw_output=$(_shsh_async_redraw; print -n -- marker)
assert_equal marker "$_redraw_output" 'does not print a blank line during asynchronous redraw'

typeset -ga _zle_calls=()
zle() {
  (( $# )) && _zle_calls+=("$*")
  return 0
}
CONTEXT=cont
_shsh_async_redraw
assert_equal 0 "${#_zle_calls}" 'does not reset the prompt during continuation input'
CONTEXT=start
_shsh_async_redraw
assert_equal .reset-prompt "${_zle_calls[-1]}" 'uses the builtin reset-prompt widget'

COLUMNS=100
_shsh_render
typeset _wide_prompt=$_shsh_rendered_prompt
COLUMNS=60
typeset _expanded_prompt=$(_shsh_expand_prompt)
_shsh_render
assert_equal "$_shsh_rendered_prompt" "$_expanded_prompt" \
  'expands the prompt with the current terminal width'
assert_true '[[ $_expanded_prompt != $_wide_prompt ]]' \
  'changes the rendered prompt when the terminal width changes'
assert_true \
  '(( ${(m)#_shsh_render_left_plain} + _shsh_render_padding + ${(m)#_shsh_render_right_plain} == COLUMNS ))' \
  'realigns the right segment to the resized terminal width'
CONTEXT=start
COLUMNS=80
unfunction zle
unset CONTEXT

assert_equal '' "$PROMPT_EOL_MARK" 'hides the end-of-line marker like Pure'

typeset _saved_title_prefix=$_shsh_title_prefix
SSH_CONNECTION='192.0.2.1 22 192.0.2.2 22'
_shsh_detect_identity
assert_equal "${(%):-%m} " "$_shsh_title_prefix" \
  'detects the SSH hostname prefix during setup'
_shsh_title_prefix='remote '
typeset _title_output=$(TERM=xterm-256color TTY=/dev/ttys001 _shsh_set_title path)
assert_equal $'\e]0;remote path\a' "$_title_output" \
  'includes the SSH hostname prefix in the terminal title'
_shsh_title_prefix=$_saved_title_prefix
unset SSH_CONNECTION

typeset _original_pwd=$PWD
typeset _nonrepo_root=$(mktemp -d "${TMPDIR:-/tmp}/prompt-shsh-nonrepo.XXXXXXXX")
_shsh_git_branch=main
_shsh_update_git_render
_shsh_render
_shsh_async_pwd=$PWD
functions[_saved_async_init]=$functions[_shsh_async_init]
_shsh_async_init() {
  return 1
}
builtin cd -q -- "$_nonrepo_root"
_shsh_async_refresh || true
assert_equal '' "$_shsh_git_prompt" \
  'clears Git state immediately after leaving a repository'
_shsh_render
assert_true '[[ $_shsh_rendered_prompt != *main* ]]' \
  'removes the stale Git segment even when the worker cannot start'
builtin cd -q -- "$_original_pwd"
_shsh_async_pwd=$PWD
functions[_shsh_async_init]=$functions[_saved_async_init]
unfunction _saved_async_init
rm -rf -- "$_nonrepo_root"

typeset -gi _zpty_checks=0 _flushes=0
typeset -ga _flushed_workers=()
zpty() {
  (( ++_zpty_checks ))
  return 0
}
async_flush_jobs() {
  (( ++_flushes ))
  _flushed_workers+=("$1")
}
async_job() {
  return 0
}
functions[_saved_kube_signature]=$functions[_shsh_kube_signature]
_shsh_kube_signature() {
  return 1
}
_shsh_kube_context=old-context
_shsh_kube_namespace=old-namespace
_shsh_update_kube_render
_shsh_render
assert_contains "$_shsh_rendered_prompt" 'old-context/old-namespace' \
  'renders a cached Kubernetes segment before its config disappears'
_shsh_async_ready=1
_shsh_async_refresh
assert_equal '' "$_shsh_kube_prompt" \
  'clears Kubernetes data when its config disappears'
_shsh_render
assert_true '[[ $_shsh_rendered_prompt != *old-context* ]]' \
  'removes a stale Kubernetes segment in the same prompt'
assert_equal 1 "$_zpty_checks" 'checks a ready worker only once per refresh'
assert_equal 1 "$_flushes" 'flushes jobs after reusing a live worker'
assert_equal _shsh "${_flushed_workers[1]}" \
  'local refresh flushes only the local Git worker'
unfunction zpty async_flush_jobs async_job
functions[_shsh_kube_signature]=$functions[_saved_kube_signature]
unfunction _saved_kube_signature

typeset -ga _queued_workers=() _queued_functions=()
zpty() {
  return 0
}
async_job() {
  _queued_workers+=("$1")
  _queued_functions+=("$2")
  return 0
}
typeset _test_fetch_top=/tmp/shsh-fetch-repository
_shsh_fetch_ready=1
_shsh_fetch_interval=300
_shsh_fetch_attempted_at[$_test_fetch_top]=$(( EPOCHSECONDS - 299 ))
_shsh_maybe_fetch /tmp/shsh-fetch-repository "$_test_fetch_top"
assert_equal 0 "${#_queued_workers}" 'does not fetch again inside the five-minute interval'

_shsh_fetch_attempted_at[$_test_fetch_top]=$(( EPOCHSECONDS - 300 ))
_shsh_maybe_fetch /tmp/shsh-fetch-repository "$_test_fetch_top"
assert_equal 1 "${#_queued_workers}" 'queues fetch when the five-minute interval expires'
assert_equal _shsh_fetch "${_queued_workers[1]}" 'queues network work on the fetch worker'
assert_equal _shsh_async_git_fetch "${_queued_functions[1]}" \
  'queues the dedicated fetch job'
_shsh_maybe_fetch /tmp/shsh-fetch-repository "$_test_fetch_top"
assert_equal 1 "${#_queued_workers}" 'records the interval when the fetch is queued'
_shsh_maybe_fetch /tmp/shsh-other-repository /tmp/shsh-other-repository
assert_equal 2 "${#_queued_workers}" 'tracks the five-minute interval per repository'
unfunction zpty async_job

functions[_saved_async_redraw]=$functions[_shsh_async_redraw]
typeset -gi _fetch_redraws=0
_shsh_async_redraw() {
  (( ++_fetch_redraws ))
}
_shsh_git_top=$_test_fetch_top
_shsh_git_branch=main
_shsh_git_arrows=
_shsh_update_git_render
typeset _test_down_arrow='⇣' _test_up_arrow='⇡'
typeset _fetch_output="${(q)_test_fetch_top} 1 ${(q)_test_down_arrow}"
_shsh_fetch_callback _shsh_async_git_fetch 0 "$_fetch_output" 0 '' 0
assert_equal '⇣' "$_shsh_git_arrows" 'applies a completed fetch for the visible repository'
assert_equal 1 "$_fetch_redraws" 'redraws when fetch changes ahead or behind state'
_shsh_fetch_callback _shsh_async_git_fetch 0 "/tmp/other 1 ${(q)_test_up_arrow}" 0 '' 0
assert_equal '⇣' "$_shsh_git_arrows" 'ignores a completed fetch for another repository'
functions[_shsh_async_redraw]=$functions[_saved_async_redraw]
unfunction _saved_async_redraw

typeset -ga _foreground_flushes=()
async_flush_jobs() {
  _foreground_flushes+=("$1")
}
_shsh_fetch_ready=1
_shsh_fetch_commands=(pull fetch)
_shsh_preexec '' 'git fetch origin'
assert_equal _shsh_fetch "${_foreground_flushes[1]}" \
  'foreground fetch cancels only the network worker'
assert_true '(( _shsh_fetch_attempted_at[$_test_fetch_top] == EPOCHSECONDS ))' \
  'foreground fetch resets the repository interval'
unfunction async_flush_jobs

print -r -- "1..${_test_count}"
