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

_shsh_last_status=0
_shsh_time=12:34:56
COLUMNS=80
_shsh_render
assert_contains "$PROMPT" $'\n%F{#a6e3a1}❯%f ' 'renders a two-line success prompt'
assert_contains "$PROMPT" '%F{#89b4fa}' 'renders the path in Mocha Blue'
assert_contains "$PROMPT" '%F{#7f849c}' 'renders the clock in Mocha Overlay 1'
assert_equal 12:34:56 "$_shsh_render_right_plain" 'keeps the precmd time at the right'
assert_true '(( ${#_shsh_render_left_plain} + _shsh_render_padding + ${#_shsh_render_right_plain} == COLUMNS ))' 'aligns the right segment to the terminal edge'

_shsh_last_status=1
_shsh_render
assert_contains "$PROMPT" '%F{#f38ba8}❯%f ' 'renders failures in Mocha Red'

_shsh_command_duration='1m 2s'
COLUMNS=80
_shsh_render
assert_contains "$PROMPT" '%F{#f9e2af}1m 2s%f' 'renders slow commands in Mocha Yellow'

COLUMNS=20
_shsh_render
assert_true '(( ${#_shsh_render_left_plain} + ${#_shsh_render_right_plain} <= COLUMNS ))' 'drops low-priority right content in narrow terminals'

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
  _zle_calls+=("$*")
}
CONTEXT=cont
_shsh_async_redraw
assert_equal 0 "${#_zle_calls}" 'does not reset the prompt during continuation input'
CONTEXT=start
_shsh_async_redraw
assert_equal .reset-prompt "${_zle_calls[-1]}" 'uses the builtin reset-prompt widget'
unfunction zle
unset CONTEXT

assert_equal '' "$PROMPT_EOL_MARK" 'hides the end-of-line marker like Pure'

print -r -- "1..${_test_count}"
