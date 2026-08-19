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

prompt_shsh_human_time 5
assert_equal 5s "$REPLY" 'formats seconds'
prompt_shsh_human_time 3665
assert_equal '1h 1m 5s' "$REPLY" 'formats compound duration'
prompt_shsh_human_time 90000
assert_equal '1d 1h' "$REPLY" 'omits zero duration units'

prompt_shsh_shorten_path '~/src/project' 20
assert_equal '~/src/project' "$REPLY" 'keeps a path that fits'
prompt_shsh_shorten_path '~/one/two/three/project' 15
assert_equal '…/three/project' "$REPLY" 'shortens at component boundaries'
prompt_shsh_shorten_path '/a/very-long-component' 8
assert_equal '…mponent' "$REPLY" 'falls back to tail truncation'

prompt_shsh_last_status=0
COLUMNS=80
prompt_shsh_render
assert_contains "$PROMPT" $'\n%F{green}❯%f ' 'renders a two-line success prompt'
assert_equal 8 "${#prompt_shsh_render_right_plain}" 'renders current time at the right'
assert_true '(( ${#prompt_shsh_render_left_plain} + prompt_shsh_render_padding + ${#prompt_shsh_render_right_plain} == COLUMNS ))' 'aligns the right segment to the terminal edge'

prompt_shsh_last_status=1
prompt_shsh_render
assert_contains "$PROMPT" '%F{red}❯%f ' 'renders failures in red'

prompt_shsh_command_duration='1m 2s'
COLUMNS=20
prompt_shsh_render
assert_true '(( ${#prompt_shsh_render_left_plain} + ${#prompt_shsh_render_right_plain} <= COLUMNS ))' 'drops low-priority right content in narrow terminals'

print -r -- "1..${_test_count}"
