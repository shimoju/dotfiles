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
typeset _fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/prompt-shimoju-external.XXXXXXXX")
_fixture_root=${_fixture_root:A}
trap 'rm -rf -- "$_fixture_root"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_NOSYSTEM=1

fpath=("${_repo_root}/dot_config/zsh/prompt" $fpath)
autoload -Uz promptinit
promptinit
prompt shimoju

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
result=("${(Q@)${(z)$(prompt_shimoju_async_git_fetch 9 "$_fixture_root/local")}}")
assert_equal 1 "${result[3]}" 'background fetch succeeds without interaction'
assert_equal '⇣' "${result[4]}" 'background fetch refreshes the behind marker'

command git -C "$_fixture_root/local" config alias.sync 'pull --ff-only'
result=("${(Q@)${(z)$(prompt_shimoju_async_git_aliases 9 "$_fixture_root/local")}}")
assert_equal sync "${result[3]}" 'discovers aliases that may fetch'

prompt_shimoju_fetch_commands=(pull fetch sync)
assert_success 'detects a foreground fetch' \
  prompt_shimoju_command_conflicts_with_fetch 'git -C repo fetch origin'
assert_success 'detects a fetching Git alias' \
  prompt_shimoju_command_conflicts_with_fetch 'command git sync'

mkdir -p "$_fixture_root/bin" "$_fixture_root/kube"
print -r -- '#!/bin/sh' > "$_fixture_root/bin/kubectl"
print -r -- 'printf '\''context-a\tnamespace-a'\''' >> "$_fixture_root/bin/kubectl"
chmod +x "$_fixture_root/bin/kubectl"
print -r -- 'apiVersion: v1' > "$_fixture_root/kube/config"

PATH="$_fixture_root/bin:$PATH"
rehash
KUBECONFIG="$_fixture_root/kube/config"
prompt_shimoju_kube_signature
typeset _signature=$REPLY
result=("${(Q@)${(z)$(prompt_shimoju_async_kube 9 "$PWD" "$_signature" "$KUBECONFIG")}}")
assert_equal context-a "${result[4]}" 'reads the current Kubernetes context locally'
assert_equal namespace-a "${result[5]}" 'reads the current Kubernetes namespace locally'

prompt_shimoju_kube_context=${result[4]}
prompt_shimoju_kube_namespace=${result[5]}
prompt_shimoju_update_kube_render
assert_equal '⎈ context-a/namespace-a' "$prompt_shimoju_kube_plain" 'builds the Kubernetes segment'

print -r -- "1..${_test_count}"
