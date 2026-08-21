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
assert_equal '' "${result[4]}" 'reports no conflict in an ordinary dirty tree'
assert_equal '≡' "${result[5]}" 'reports a stash'
result=("${(Q@)${(z)$(_shsh_async_git_arrows 7 "$_fixture_root")}}")
assert_equal '⇣⇡' "${result[3]}" 'reports diverged upstream state independently'

_shsh_generation=8
_shsh_git_branch=keep
_shsh_async_callback _shsh_async_git_branch 0 \
  "$(_shsh_async_git_branch 7 "$_fixture_root")" 0 '' 0
assert_equal keep "$_shsh_git_branch" 'rejects a stale generation'

builtin cd -q -- "$_fixture_root"
_shsh_generation=7
typeset -ga _queued_jobs=()
typeset -gi _redraw_count=0
async_job() {
  _queued_jobs+=("$2")
}
functions[_saved_async_redraw]=$functions[_shsh_async_redraw]
_shsh_async_redraw() {
  (( ++_redraw_count ))
}
_shsh_async_render_requested=1
_shsh_async_callback _shsh_async_git_branch 0 \
  "$(_shsh_async_git_branch 6 "$_fixture_root")" 0 '' 0
assert_equal 1 "$_redraw_count" 'flushes a deferred redraw after a stale result'
assert_equal 0 "$_shsh_async_render_requested" 'clears the deferred redraw flag'
_redraw_count=0
_shsh_async_callback _shsh_async_git_branch 0 \
  "$(_shsh_async_git_branch 7 "$_fixture_root")" 0 '' 0
assert_equal main "$_shsh_git_branch" 'accepts the current branch generation'
assert_equal _shsh_async_git_arrows "${_queued_jobs[1]}" \
  'queues ahead and behind after the branch is known'
assert_equal _shsh_async_git_aliases "${_queued_jobs[-1]}" \
  'queues alias discovery after entering a repository'
assert_equal 1 "$_redraw_count" 'redraws when the branch changes'
unfunction async_job
_shsh_async_callback _shsh_async_git_arrows 0 \
  "$(_shsh_async_git_arrows 7 "$_fixture_root")" 0 '' 0
assert_equal 2 "$_redraw_count" 'redraws when ahead or behind state changes'
_shsh_async_callback _shsh_async_git_status 0 \
  "$(_shsh_async_git_status 7 "$_fixture_root")" 0 '' 0
assert_equal 'main*+? ⇣⇡ ≡' "$_shsh_git_plain" 'builds a unified Git segment'
assert_equal '%F{#cba6f7}main%f%F{#fab387}*+?%f %F{#94e2d5}⇣⇡%f %F{#f5e0dc}≡%f' \
  "$_shsh_git_prompt" 'applies the Structured Mauve Git colors'
assert_equal 3 "$_redraw_count" 'redraws when the Git status changes'
_shsh_async_callback _shsh_async_git_status 0 \
  "$(_shsh_async_git_status 7 "$_fixture_root")" 0 '' 0
assert_equal 3 "$_redraw_count" 'skips redraw when the Git status is unchanged'

mkdir -p "$_fixture_root/fake-bin"
typeset _fake_git="$_fixture_root/fake-bin/git"
{
  print -r -- '#!/bin/sh'
  print -r -- "printf '%s\\n' '? partial'"
  print -r -- 'exit 42'
} > "$_fake_git"
command chmod +x "$_fake_git"

typeset _failed_status_output
typeset -i _failed_status_code=0
_failed_status_output=$(PATH="${_fake_git:h}:$PATH" \
  _shsh_async_git_status 7 "$_fixture_root") || _failed_status_code=$?
result=("${(Q@)${(z)_failed_status_output}}")
assert_equal 42 "$_failed_status_code" 'propagates a failed git status exit code'
assert_equal 5 "${#result}" 'keeps the result envelope on git status failure'
assert_equal '?' "${result[3]}" 'parses output emitted before git status fails'

_shsh_async_callback _shsh_async_git_status "$_failed_status_code" \
  "$_failed_status_output" 0 '' 0
assert_equal 1 "$_shsh_git_unknown" 'marks a failed git status as unknown'
assert_equal '' "$_shsh_git_dirty" 'discards partial dirty state on failure'
assert_equal 'main! ⇣⇡' "$_shsh_git_plain" 'renders unknown beside the branch'
assert_equal '%F{#cba6f7}main%f%F{#f9e2af}!%f %F{#94e2d5}⇣⇡%f' \
  "$_shsh_git_prompt" 'renders unknown in the warning color'
assert_equal 4 "$_redraw_count" 'redraws when Git status becomes unknown'

_shsh_async_callback _shsh_async_git_status 0 \
  "$(_shsh_async_git_status 7 "$_fixture_root")" 0 '' 0
assert_equal 0 "$_shsh_git_unknown" 'clears unknown after git status recovers'
assert_equal 'main*+? ⇣⇡ ≡' "$_shsh_git_plain" 'restores status after recovery'
assert_equal 5 "$_redraw_count" 'redraws when Git status recovers'

typeset _stale_failed_output
_stale_failed_output=$(PATH="${_fake_git:h}:$PATH" \
  _shsh_async_git_status 6 "$_fixture_root") || true
_shsh_async_callback _shsh_async_git_status 42 \
  "$_stale_failed_output" 0 '' 0
assert_equal 0 "$_shsh_git_unknown" 'rejects unknown from a stale generation'
assert_equal 5 "$_redraw_count" 'does not redraw for a stale failure'
functions[_shsh_async_redraw]=$functions[_saved_async_redraw]
unfunction _saved_async_redraw

typeset _detached_head=$(command git -C "$_fixture_root" rev-parse --short HEAD)
command git -C "$_fixture_root" switch -q --detach HEAD
result=("${(Q@)${(z)$(_shsh_async_git_branch 7 "$_fixture_root")}}")
assert_equal "$_detached_head" "${result[4]}" 'reports the short hash for detached HEAD'
command git -C "$_fixture_root" switch -q main

mkdir -p "$_fixture_root/unborn"
command git -C "$_fixture_root/unborn" init -q -b fresh
result=("${(Q@)${(z)$(_shsh_async_git_branch 7 "$_fixture_root/unborn")}}")
assert_equal "$_fixture_root/unborn" "${result[3]}" \
  'reports the top-level of an unborn repository'
assert_equal fresh "${result[4]}" 'reports an unborn branch'

mkdir -p "$_fixture_root/conflict"
command git -C "$_fixture_root/conflict" init -q -b main
command git -C "$_fixture_root/conflict" config user.name test
command git -C "$_fixture_root/conflict" config user.email test@example.com
print -r -- base > "$_fixture_root/conflict/tracked"
command git -C "$_fixture_root/conflict" add tracked
command git -C "$_fixture_root/conflict" commit -qm initial
command git -C "$_fixture_root/conflict" switch -qc other
print -r -- other > "$_fixture_root/conflict/tracked"
command git -C "$_fixture_root/conflict" commit -qam other
command git -C "$_fixture_root/conflict" switch -q main
print -r -- main > "$_fixture_root/conflict/tracked"
command git -C "$_fixture_root/conflict" commit -qam main
command git -C "$_fixture_root/conflict" merge -q other >/dev/null 2>&1 || true
result=("${(Q@)${(z)$(_shsh_async_git_status 7 "$_fixture_root/conflict")}}")
assert_equal '' "${result[3]}" 'does not classify a conflict as ordinary dirty state'
assert_equal '#' "${result[4]}" 'reports a conflict with its dedicated marker'
_shsh_git_branch=main
_shsh_git_dirty=${result[3]}
_shsh_git_conflict=${result[4]}
_shsh_git_action=merge
_shsh_git_arrows=
_shsh_git_stash=${result[5]}
_shsh_update_git_render
assert_equal 'main# merge' "$_shsh_git_plain" 'places the conflict marker beside the branch'
assert_equal '%F{#cba6f7}main%f%F{#f38ba8}#%f %F{#f5c2e7}merge%f' \
  "$_shsh_git_prompt" 'renders the conflict marker in Catppuccin Red'

mkdir -p "$_fixture_root/.git/rebase-merge"
: > "$_fixture_root/.git/rebase-merge/interactive"
result=("${(Q@)${(z)$(_shsh_async_git_branch 7 "$_fixture_root")}}")
assert_equal rebase-i "${result[5]}" 'reports an interactive rebase action'

print -r -- "1..${_test_count}"
