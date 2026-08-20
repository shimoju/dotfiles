#!/usr/bin/env zsh

emulate -R zsh
setopt pipefail

: ${ASYNC_ZSH_PATH:?set ASYNC_ZSH_PATH to zsh-async/async.zsh}

typeset -gi _test_count=0
typeset -gi _test_failed=0

assert_equal() {
  local expected=$1 actual=$2 message=$3
  (( ++_test_count ))
  if [[ $actual != $expected ]]; then
    print -u2 -r -- "not ok ${_test_count} - ${message}"
    print -u2 -r -- "  expected: ${(qqq)expected}"
    print -u2 -r -- "  actual:   ${(qqq)actual}"
    _test_failed=1
    return 0
  fi
  print -r -- "ok ${_test_count} - ${message}"
}

assert_not_equal() {
  local unexpected=$1 actual=$2 message=$3
  (( ++_test_count ))
  if [[ $actual == $unexpected ]]; then
    print -u2 -r -- "not ok ${_test_count} - ${message}"
    print -u2 -r -- "  unexpected: ${(qqq)unexpected}"
    _test_failed=1
    return 0
  fi
  print -r -- "ok ${_test_count} - ${message}"
}

typeset _repo_root=${0:A:h:h:h}
typeset _repo_branch=$(command git -C "$_repo_root" branch --show-current)
typeset _fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/prompt-shsh-async.XXXXXXXX")
_fixture_root=${_fixture_root:A}
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_NOSYSTEM=1

cleanup() {
  async_stop_worker _shsh 2>/dev/null || true
  async_stop_worker _shsh_fetch 2>/dev/null || true
  rm -rf -- "$_fixture_root"
}
trap cleanup EXIT

source "$ASYNC_ZSH_PATH"
command git -C "$_fixture_root" init -q -b main
command git -C "$_fixture_root" config user.name test
command git -C "$_fixture_root" config user.email test@example.com
command git -C "$_fixture_root" config alias.pl pull
print -r -- base > "$_fixture_root/tracked"
command git -C "$_fixture_root" add tracked
command git -C "$_fixture_root" commit -qm initial
print -r -- untracked > "$_fixture_root/untracked"

builtin cd -q -- "$_fixture_root"
fpath=("${_repo_root}/dot_config/zsh/prompt" $fpath)
autoload -Uz promptinit
promptinit
prompt shsh
TERM=dumb _shsh_precmd >/dev/null

repeat 40; do
  sleep 0.05
  async_process_results _shsh _shsh_async_callback 2>/dev/null || true
  [[ $_shsh_git_branch == main && $_shsh_git_dirty == '?' &&
    $_shsh_fetch_alias_top == $_fixture_root ]] && break
done

assert_equal main "$_shsh_git_branch" 'worker publishes the branch asynchronously'
assert_equal '?' "$_shsh_git_dirty" 'worker publishes untracked status asynchronously'
assert_equal 'main?' "$_shsh_git_plain" 'callback redraws the combined Git segment'
assert_equal 'pull fetch pl' "${(j: :)_shsh_fetch_commands}" \
  'worker publishes fetching aliases into the repository cache'

async_stop_worker _shsh_fetch 2>/dev/null || true
_shsh_fetch_ready=0
_shsh_fetch_attempted_at[$_fixture_root]=0
_shsh_async_git_fetch() {
  local arrows='⇣'
  sleep 0.3
  print -r -- ${(q)2} 1 ${(q)arrows}
}
_shsh_maybe_fetch "$_fixture_root" "$_fixture_root"
_shsh_async_refresh
repeat 40; do
  sleep 0.05
  async_process_results _shsh _shsh_async_callback 2>/dev/null || true
  async_process_results _shsh_fetch _shsh_fetch_callback 2>/dev/null || true
  [[ $_shsh_git_arrows == '⇣' ]] && break
done
assert_equal '⇣' "$_shsh_git_arrows" \
  'local worker refresh does not interrupt the fetch worker'

async_stop_worker _shsh_fetch
_shsh_fetch_attempted_at[$_fixture_root]=0
_shsh_maybe_fetch "$_fixture_root" "$_fixture_root"
typeset -i _fetch_worker_restarted=0
zpty -t _shsh_fetch &>/dev/null && _fetch_worker_restarted=1
assert_equal 1 "$_fetch_worker_restarted" 'fetch worker restarts after an unexpected stop'

typeset _old_generation=$_shsh_generation
builtin cd -q -- "$_repo_root"
_shsh_async_refresh
_shsh_async_callback _shsh_async_git_branch 0 \
  "$(_shsh_async_git_branch "$_old_generation" "$_fixture_root")" 0 '' 0
assert_not_equal main "$_shsh_git_branch" 'changing directory rejects the old result'

repeat 40; do
  sleep 0.05
  async_process_results _shsh _shsh_async_callback 2>/dev/null || true
  [[ $_shsh_git_branch == $_repo_branch ]] && break
done
assert_equal "$_repo_branch" "$_shsh_git_branch" 'worker publishes the new directory after cancellation'

async_stop_worker _shsh
_shsh_git_branch=
_shsh_update_git_render
_shsh_async_refresh || true
repeat 40; do
  sleep 0.05
  async_process_results _shsh _shsh_async_callback 2>/dev/null || true
  [[ $_shsh_git_branch == $_repo_branch ]] && break
done
assert_equal "$_repo_branch" "$_shsh_git_branch" 'worker restarts after an unexpected stop'

async_stop_worker _shsh
_shsh_async_ready=0
_shsh_test_slow_job() {
  sleep 0.15
  print -r -- "$1"
}
typeset -g _shsh_test_result=
_shsh_test_callback() {
  [[ $1 == _shsh_test_slow_job && $2 == 0 ]] && _shsh_test_result=$3
}
_shsh_async_init
async_unregister_callback _shsh
async_job _shsh _shsh_test_slow_job old
sleep 0.005
async_flush_jobs _shsh
async_job _shsh _shsh_test_slow_job replacement
repeat 60; do
  sleep 0.01
  async_process_results _shsh _shsh_test_callback 2>/dev/null || true
  [[ $_shsh_test_result == replacement ]] && break
done
assert_equal replacement "$_shsh_test_result" \
  'flush does not discard the replacement branch job'
unfunction _shsh_test_slow_job _shsh_test_callback

print -r -- "1..${_test_count}"
(( _test_failed == 0 ))
