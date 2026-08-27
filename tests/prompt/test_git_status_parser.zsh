#!/usr/bin/env zsh

emulate -R zsh
setopt nounset pipefail

typeset -gi _test_count=0 _test_failed=0

assert_equal() {
  local expected=$1 actual=$2 message=$3

  (( ++_test_count ))
  if [[ $actual != $expected ]]; then
    print -u2 -r -- "not ok ${_test_count} - ${message}"
    print -u2 -r -- "  expected: ${(qqq)expected}"
    print -u2 -r -- "  actual:   ${(qqq)actual}"
    _test_failed=1
    return
  fi
  print -r -- "ok ${_test_count} - ${message}"
}

typeset _repo_root=${0:A:h:h:h}
typeset _fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/prompt-shsh-parser.XXXXXXXX")
_fixture_root=${_fixture_root:A}
trap 'rm -rf -- "$_fixture_root"' EXIT

mkdir -p "$_fixture_root/fake-bin"
typeset _fake_git="$_fixture_root/fake-bin/git"
{
  print -r -- '#!/bin/sh'
  print -r -- 'printf '\''%s'\'' "${PROMPT_TEST_STATUS_OUTPUT-}"'
  print -r -- 'exit "${PROMPT_TEST_STATUS_CODE:-0}"'
} > "$_fake_git"
chmod +x "$_fake_git"

export TERM=dumb
source "$_repo_root/dot_config/zsh/prompt/prompt_shsh_setup"
add-zsh-hook -d precmd _shsh_precmd
add-zsh-hook -d preexec _shsh_preexec

assert_status() {
  local expected_dirty=$1 expected_conflict=$2 expected_stash=$3
  local description=$4 status_output=$5
  local expected_code=${6:-0} output
  local -i status_code=0
  local -a expected result actual

  output=$(PROMPT_TEST_STATUS_OUTPUT=$status_output \
    PROMPT_TEST_STATUS_CODE=$expected_code \
    PATH="${_fake_git:h}:$PATH" \
    _shsh_async_git_status 7 "$_fixture_root") || status_code=$?
  result=("${(Q@)${(z)output}}")

  expected=("$expected_code" 7 "$_fixture_root" \
    "$expected_dirty" "$expected_conflict" "$expected_stash")
  actual=("$status_code" "${result[@]}")
  assert_equal "${(j:|:)expected}" "${(j:|:)actual}" "$description"
}

typeset _hash1=1111111111111111111111111111111111111111
typeset _hash2=2222222222222222222222222222222222222222
typeset _hash3=3333333333333333333333333333333333333333

assert_status '' '' '' 'empty status' ''
assert_status '' '' '' 'headers and ignored records' $'# branch.head main\n! ignored'
assert_status '+' '' '' 'ordinary staged record' \
  "1 M. N... 100644 100644 100644 $_hash1 $_hash2 staged"
assert_status '*' '' '' 'ordinary unstaged record' \
  "1 .M N... 100644 100644 100644 $_hash1 $_hash2 unstaged"
assert_status '*+' '' '' 'ordinary staged and unstaged record' \
  "1 MM N... 100644 100644 100644 $_hash1 $_hash2 both"
assert_status '+' '' '' 'renamed staged record' \
  $'2 R. N... 100644 100644 100644 '"$_hash1 $_hash2 R100 renamed\toriginal"
assert_status '*' '' '' 'renamed unstaged record' \
  $'2 .M N... 100644 100644 100644 '"$_hash1 $_hash2 R100 renamed\toriginal"
assert_status '?' '' '' 'untracked record' '? untracked'
assert_status '' '#' '' 'unmerged record' \
  "u UU N... 100644 100644 100644 100644 $_hash1 $_hash2 $_hash3 conflicted"
assert_status '' '' '≡' 'stash header' '# stash 12'
assert_status '*+?' '#' '≡' 'combined report' \
  $'# branch.head main\n# stash 2\n1 M. N... 100644 100644 100644 '"$_hash1 $_hash2 staged"$'\n1 .M N... 100644 100644 100644 '"$_hash1 $_hash2 unstaged"$'\n? untracked\nu UU N... 100644 100644 100644 100644 '"$_hash1 $_hash2 $_hash3 conflicted"
assert_status '?' '' '' 'partial failed report' '? partial' 42

print -r -- "1..${_test_count}"
(( _test_failed == 0 ))
