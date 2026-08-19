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

typeset _repo_root=${0:A:h:h:h}
typeset _fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/prompt-shimoju-async.XXXXXXXX")
_fixture_root=${_fixture_root:A}

cleanup() {
  async_stop_worker prompt_shimoju 2>/dev/null || true
  rm -rf -- "$_fixture_root"
}
trap cleanup EXIT

source "$ASYNC_ZSH_PATH"
command git -C "$_fixture_root" init -q -b main
command git -C "$_fixture_root" config user.name test
command git -C "$_fixture_root" config user.email test@example.com
print -r -- base > "$_fixture_root/tracked"
command git -C "$_fixture_root" add tracked
command git -C "$_fixture_root" commit -qm initial
print -r -- untracked > "$_fixture_root/untracked"

builtin cd -q -- "$_fixture_root"
fpath=("${_repo_root}/dot_config/zsh/prompt" $fpath)
autoload -Uz promptinit
promptinit
prompt shimoju

repeat 40; do
  sleep 0.05
  async_process_results prompt_shimoju prompt_shimoju_async_callback 2>/dev/null || true
  [[ $prompt_shimoju_git_branch == main && $prompt_shimoju_git_dirty == '?' ]] && break
done

assert_equal main "$prompt_shimoju_git_branch" 'worker publishes the branch asynchronously'
assert_equal '?' "$prompt_shimoju_git_dirty" 'worker publishes untracked status asynchronously'
assert_equal 'main?' "$prompt_shimoju_git_plain" 'callback redraws the combined Git segment'

typeset _old_generation=$prompt_shimoju_generation
builtin cd -q -- "$_repo_root"
prompt_shimoju_async_refresh
prompt_shimoju_async_callback prompt_shimoju_async_git_branch 0 \
  "$(prompt_shimoju_async_git_branch "$_old_generation" "$_fixture_root")" 0 '' 0
assert_equal '' "$prompt_shimoju_git_branch" 'changing directory clears and rejects the old result'

repeat 40; do
  sleep 0.05
  async_process_results prompt_shimoju prompt_shimoju_async_callback 2>/dev/null || true
  [[ $prompt_shimoju_git_branch == custom-zsh-prompt ]] && break
done
assert_equal custom-zsh-prompt "$prompt_shimoju_git_branch" 'worker publishes the new directory after cancellation'

async_stop_worker prompt_shimoju
prompt_shimoju_git_branch=
prompt_shimoju_update_git_render
prompt_shimoju_async_refresh || true
repeat 40; do
  sleep 0.05
  async_process_results prompt_shimoju prompt_shimoju_async_callback 2>/dev/null || true
  [[ $prompt_shimoju_git_branch == custom-zsh-prompt ]] && break
done
assert_equal custom-zsh-prompt "$prompt_shimoju_git_branch" 'worker restarts after an unexpected stop'

print -r -- "1..${_test_count}"
(( _test_failed == 0 ))
