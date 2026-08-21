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

typeset _repo_root=${0:A:h:h:h}
typeset _fixture_root=${$(mktemp -d "${TMPDIR:-/tmp}/zsh-base.XXXXXXXX"):A}
typeset _original_path=$PATH
typeset _original_home=$HOME
typeset _original_data_home=${XDG_DATA_HOME-}

cleanup() {
  builtin cd -q -- "$_repo_root"
  rm -rf -- "$_fixture_root"
}
trap cleanup EXIT

mkdir -p "$_fixture_root/bin" "$_fixture_root/home"
print -r -- $'#!/bin/sh\nexit 0' > "$_fixture_root/bin/fzf"
chmod +x "$_fixture_root/bin/fzf"

PATH="$_fixture_root/bin:/usr/bin:/bin"
HOME="$_fixture_root/home"
XDG_DATA_HOME="$_fixture_root/data"
rehash
setopt noerrexit
source "$_repo_root/dot_config/zsh/dot_zshrc.d/00_base.zsh"
typeset -i _source_status=$?
setopt errexit
PATH=$_original_path
HOME=$_original_home
XDG_DATA_HOME=$_original_data_home
assert_equal 0 "$_source_status" 'loads the base configuration with fzf available'

typeset -ga _zle_calls=()
zle() {
  _zle_calls+=("$*")
  return 0
}

typeset _start_pwd=$PWD
typeset _target_dir="$_fixture_root/target"
mkdir -p "$_target_dir"

f() {
  builtin cd -- "$_target_dir"
}
_ghq_fzf_cd_widget
assert_equal "$_target_dir" "$PWD" 'changes directory inside the widget'
assert_equal '.redisplay .kill-buffer .accept-line' "${(j: :)_zle_calls}" \
  'restores the old prompt before accepting the line'

builtin cd -- "$_start_pwd"
_zle_calls=()
f() {
  return 1
}
_ghq_fzf_cd_widget
assert_equal "$_start_pwd" "$PWD" 'keeps the directory when selection is cancelled'
assert_equal '.reset-prompt' "${(j: :)_zle_calls}" \
  'restores the current prompt after cancellation'

_zle_calls=()
f() {
  builtin cd -- "$_start_pwd"
}
_ghq_fzf_cd_widget
assert_equal '.reset-prompt' "${(j: :)_zle_calls}" \
  'does not create a new prompt when the directory is unchanged'
