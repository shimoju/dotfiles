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
typeset _fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/prompt-shsh-git.XXXXXXXX")
_fixture_root=${_fixture_root:A}
trap 'rm -rf -- "$_fixture_root"' EXIT

fpath=("${_repo_root}/dot_config/zsh/prompt" $fpath)
autoload -Uz promptinit
promptinit
prompt shsh

command git -C "$_fixture_root" init -q -b main
command git -C "$_fixture_root" config user.name test
command git -C "$_fixture_root" config user.email test@example.com
print -r -- base > "$_fixture_root/tracked"
command git -C "$_fixture_root" add tracked
command git -C "$_fixture_root" commit -qm initial
command git -C "$_fixture_root" branch upstream

print -r -- main >> "$_fixture_root/tracked"
command git -C "$_fixture_root" commit -qam main
command git -C "$_fixture_root" switch -q upstream
print -r -- upstream > "$_fixture_root/upstream"
command git -C "$_fixture_root" add upstream
command git -C "$_fixture_root" commit -qm upstream
command git -C "$_fixture_root" switch -q main
command git -C "$_fixture_root" branch --set-upstream-to=upstream >/dev/null

print -r -- stash >> "$_fixture_root/tracked"
command git -C "$_fixture_root" stash push -qm test
print -r -- unstaged >> "$_fixture_root/tracked"
print -r -- staged > "$_fixture_root/staged"
command git -C "$_fixture_root" add staged
print -r -- untracked > "$_fixture_root/untracked"

typeset -a result
result=("${(Q@)${(z)$(_shsh_async_git_branch 7 "$_fixture_root")}}")
assert_equal 7 "${result[1]}" 'branch result includes its generation'
assert_equal "$_fixture_root" "${result[2]}" 'branch result includes its working directory'
assert_equal main "${result[4]}" 'reports the current branch'

result=("${(Q@)${(z)$(_shsh_async_git_status 7 "$_fixture_root")}}")
assert_equal '*+?' "${result[3]}" 'reports unstaged, staged, and untracked changes'
assert_equal '⇣⇡' "${result[4]}" 'reports diverged upstream state'
assert_equal '≡' "${result[5]}" 'reports a stash'

_shsh_generation=8
_shsh_git_branch=keep
_shsh_async_callback _shsh_async_git_branch 0 \
  "$(_shsh_async_git_branch 7 "$_fixture_root")" 0 '' 0
assert_equal keep "$_shsh_git_branch" 'rejects a stale generation'

builtin cd -q -- "$_fixture_root"
_shsh_generation=7
_shsh_async_callback _shsh_async_git_branch 0 \
  "$(_shsh_async_git_branch 7 "$_fixture_root")" 0 '' 0
assert_equal main "$_shsh_git_branch" 'accepts the current branch generation'
_shsh_async_callback _shsh_async_git_status 0 \
  "$(_shsh_async_git_status 7 "$_fixture_root")" 0 '' 0
assert_equal 'main*+? ⇣⇡ ≡' "$_shsh_git_plain" 'builds a unified Git segment'
assert_equal '%F{#cba6f7}main%f%F{#fab387}*+?%f %F{#94e2d5}⇣⇡%f %F{#f5e0dc}≡%f' \
  "$_shsh_git_prompt" 'applies the Structured Mauve Git colors'

typeset _detached_head=$(command git -C "$_fixture_root" rev-parse --short HEAD)
command git -C "$_fixture_root" switch -q --detach HEAD
result=("${(Q@)${(z)$(_shsh_async_git_branch 7 "$_fixture_root")}}")
assert_equal "$_detached_head" "${result[4]}" 'reports the short hash for detached HEAD'
command git -C "$_fixture_root" switch -q main

mkdir -p "$_fixture_root/.git/rebase-merge"
: > "$_fixture_root/.git/rebase-merge/interactive"
result=("${(Q@)${(z)$(_shsh_async_git_branch 7 "$_fixture_root")}}")
assert_equal rebase-i "${result[5]}" 'reports an interactive rebase action'

print -r -- "1..${_test_count}"
