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

assert_success() {
  local message=$1
  shift
  (( ++_test_count ))
  if ! "$@"; then
    print -u2 -r -- "not ok ${_test_count} - ${message}"
    return 1
  fi
  print -r -- "ok ${_test_count} - ${message}"
}

typeset _repo_root=${0:A:h:h:h}
typeset _fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/prompt-shsh-external.XXXXXXXX")
_fixture_root=${_fixture_root:A}
trap 'rm -rf -- "$_fixture_root"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_NOSYSTEM=1

fpath=("${_repo_root}/dot_config/zsh/prompt" $fpath)
autoload -Uz promptinit
promptinit
prompt shsh

command git init -q --bare "$_fixture_root/remote.git"
command git init -q -b main "$_fixture_root/local"
command git -C "$_fixture_root/local" remote add origin "$_fixture_root/remote.git"
command git -C "$_fixture_root/local" config user.name test
command git -C "$_fixture_root/local" config user.email test@example.com
print -r -- initial > "$_fixture_root/local/tracked"
command git -C "$_fixture_root/local" add tracked
command git -C "$_fixture_root/local" commit -qm initial
command git -C "$_fixture_root/local" push -qu origin HEAD:main
command git -C "$_fixture_root/local" branch -u origin/main >/dev/null
command git --git-dir="$_fixture_root/remote.git" symbolic-ref HEAD refs/heads/main

command git clone -q "$_fixture_root/remote.git" "$_fixture_root/other"
command git -C "$_fixture_root/other" config user.name test
command git -C "$_fixture_root/other" config user.email test@example.com
print -r -- remote >> "$_fixture_root/other/tracked"
command git -C "$_fixture_root/other" commit -qam remote
command git -C "$_fixture_root/other" push -q

typeset -a result
result=("${(Q@)${(z)$(_shsh_async_git_fetch 9 "$_fixture_root/local")}}")
assert_equal 1 "${result[3]}" 'background fetch succeeds without interaction'
assert_equal '⇣' "${result[4]}" 'background fetch refreshes the behind marker'

mkdir -p "$_fixture_root/fetch-bin"
print -r -- '#!/bin/sh' > "$_fixture_root/fetch-bin/git"
print -r -- 'case "$1" in' >> "$_fixture_root/fetch-bin/git"
print -r -- '  rev-parse) printf '\''%s\n'\'' "$PROMPT_TEST_GIT_TOP" ;;' >> "$_fixture_root/fetch-bin/git"
print -r -- '  rev-list) printf '\''0\t0\n'\'' ;;' >> "$_fixture_root/fetch-bin/git"
print -r -- '  -c) printf '\''%s\n%s:%s\n'\'' "$*" "${GPG_TTY+x}" "${GPG_TTY-}" > "$PROMPT_TEST_GIT_LOG" ;;' >> "$_fixture_root/fetch-bin/git"
print -r -- 'esac' >> "$_fixture_root/fetch-bin/git"
chmod +x "$_fixture_root/fetch-bin/git"

typeset _saved_path=$PATH
PATH="$_fixture_root/fetch-bin:$PATH"
rehash
export PROMPT_TEST_GIT_TOP=$_fixture_root/local
export PROMPT_TEST_GIT_LOG=$_fixture_root/fetch.log
result=("${(Q@)${(z)$(_shsh_async_git_fetch 9 "$_fixture_root/local")}}")
assert_equal 1 "${result[3]}" 'runs lightweight fetch inside a working tree'
typeset -a _fetch_log=("${(@f)$(<"$PROMPT_TEST_GIT_LOG")}")
assert_equal '-c gc.auto=0 -c maintenance.auto=0 -c fetch.prune=false fetch --quiet --no-tags --no-prune-tags --recurse-submodules=no' \
  "${_fetch_log[1]}" 'disables tags, pruning, and submodules during background fetch'
assert_equal 'x:' "${_fetch_log[2]}" 'exports an empty GPG_TTY to background fetch'

PROMPT_TEST_GIT_TOP=$HOME
PROMPT_TEST_GIT_LOG=$_fixture_root/home-fetch.log
result=("${(Q@)${(z)$(_shsh_async_git_fetch 9 "$_fixture_root/local")}}")
assert_equal 0 "${result[3]}" 'skips background fetch when HOME is the repository root'
assert_success 'does not invoke fetch for a repository rooted at HOME' \
  test ! -e "$PROMPT_TEST_GIT_LOG"
PATH=$_saved_path
rehash
unset PROMPT_TEST_GIT_TOP PROMPT_TEST_GIT_LOG

command git -C "$_fixture_root/local" config alias.sync 'pull --ff-only'
command git -C "$_fixture_root/local" config alias.shell-sync '!git fetch --all'
command git -C "$_fixture_root/local" config alias.review 'show refs/pull/123'
command git -C "$_fixture_root/local" config alias.search 'log --grep=fetch'
typeset _local_top=$(command git -C "$_fixture_root/local" rev-parse --show-toplevel)
typeset _other_top=$(command git -C "$_fixture_root/other" rev-parse --show-toplevel)
typeset _alias_output=$(_shsh_async_git_aliases 9 "$_fixture_root/local" "$_local_top")
result=("${(Q@)${(z)_alias_output}}")
assert_equal "$_local_top" "${result[3]}" 'keys fetching aliases by Git top-level'
assert_equal 'sync shell-sync' "${result[4]}" \
  'discovers fetching aliases without substring false positives'

typeset _original_pwd=$PWD
builtin cd -q -- "$_fixture_root/local"
_shsh_generation=9
_shsh_git_top=$_local_top
_shsh_async_callback _shsh_async_git_aliases 0 "$_alias_output" 0 '' 0
assert_equal "$_local_top" "$_shsh_fetch_alias_top" 'caches aliases for the current repository'
assert_equal 'pull fetch sync shell-sync' "${(j: :)_shsh_fetch_commands}" 'adds cached aliases to fetch commands'
assert_success 'detects a foreground fetch' \
  _shsh_command_conflicts_with_fetch 'git -C repo fetch origin'
assert_success 'detects a fetching Git alias' \
  _shsh_command_conflicts_with_fetch 'command git sync'
assert_success 'detects a shell Git alias that fetches' \
  _shsh_command_conflicts_with_fetch 'git shell-sync'

typeset -ga _queued_jobs=()
async_job() {
  _queued_jobs+=("$2")
}

_shsh_fetch_commands=(pull fetch)
_shsh_update_fetch_aliases 10 "$_fixture_root/local/subdir" "$_local_top"
assert_equal 'pull fetch sync shell-sync' "${(j: :)_shsh_fetch_commands}" \
  'reuses aliases in a subdirectory of the same repository'
assert_equal 0 "${#_queued_jobs}" 'does not queue an alias job on a cache hit'

_shsh_update_fetch_aliases 10 "$_fixture_root/other" "$_other_top"
assert_equal 'pull fetch' "${(j: :)_shsh_fetch_commands}" \
  'uses safe defaults while a different repository loads'
assert_equal _shsh_async_git_aliases "${_queued_jobs[-1]}" \
  'queues an alias job after changing repositories'

builtin cd -q -- "$_fixture_root/other"
_shsh_generation=10
_shsh_git_top=$_other_top
typeset _empty_alias_output=$(_shsh_async_git_aliases 10 "$_fixture_root/other" "$_other_top")
_shsh_async_callback _shsh_async_git_aliases 0 "$_empty_alias_output" 0 '' 0
assert_equal "$_other_top" "$_shsh_fetch_alias_top" 'caches an empty alias result'
assert_equal 0 "${#_shsh_fetch_aliases}" 'represents an empty alias cache explicitly'

_queued_jobs=()
_shsh_update_fetch_aliases 11 "$_fixture_root/other" "$_other_top"
assert_equal 0 "${#_queued_jobs}" 'does not retry an empty alias cache'

_shsh_async_callback _shsh_async_git_aliases 0 "$_alias_output" 0 '' 0
assert_equal "$_other_top" "$_shsh_fetch_alias_top" \
  'rejects an alias result from a different repository'

builtin cd -q -- "$_fixture_root"
_shsh_generation=11
typeset _nonrepo_output=$(setopt noerrexit; _shsh_async_git_branch 11 "$_fixture_root")
result=("${(Q@)${(z)_nonrepo_output}}")
assert_equal 5 "${#result}" 'returns a complete branch result outside a repository'
assert_equal '' "${result[3]-}" 'reports no Git top-level outside a repository'
_shsh_async_callback _shsh_async_git_branch 0 "$_nonrepo_output" 0 '' 0
assert_equal '' "$_shsh_fetch_alias_top" 'clears the alias cache outside a Git repository'
builtin cd -q -- "$_original_pwd"
unfunction async_job

mkdir -p "$_fixture_root/bin" "$_fixture_root/kube"
print -r -- '#!/bin/sh' > "$_fixture_root/bin/kubectl"
print -r -- 'printf '\''context-a\tnamespace-a'\''' >> "$_fixture_root/bin/kubectl"
chmod +x "$_fixture_root/bin/kubectl"
print -r -- 'apiVersion: v1' > "$_fixture_root/kube/config"

PATH="$_fixture_root/bin:$PATH"
rehash
KUBECONFIG="$_fixture_root/kube/config"
_shsh_kube_signature
typeset _signature=$REPLY
result=("${(Q@)${(z)$(_shsh_async_kube 9 "$PWD" "$_signature" "$KUBECONFIG")}}")
assert_equal context-a "${result[4]}" 'reads the current Kubernetes context locally'
assert_equal namespace-a "${result[5]}" 'reads the current Kubernetes namespace locally'

_shsh_kube_context=${result[4]}
_shsh_kube_namespace=${result[5]}
_shsh_update_kube_render
assert_equal '⎈ context-a/namespace-a' "$_shsh_kube_plain" 'builds the Kubernetes segment'
assert_equal '%F{#74c7ec}⎈ context-a/namespace-a%f' "$_shsh_kube_prompt" \
  'renders Kubernetes in Mocha Sapphire'

print -r -- "1..${_test_count}"
