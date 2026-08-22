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
typeset _fixture_root=${$(mktemp -d "${TMPDIR:-/tmp}/zsh-security.XXXXXXXX"):A}

cleanup() {
  builtin cd -q -- "$_repo_root"
  rm -rf -- "$_fixture_root"
}
trap cleanup EXIT

mkdir -p \
  "$_fixture_root/home" \
  "$_fixture_root/data/safe-chain/bin" \
  "$_fixture_root/data/safe-chain/scripts"
print -r -- $'#!/bin/sh\nexit 0' > "$_fixture_root/data/safe-chain/bin/safe-chain"
chmod +x "$_fixture_root/data/safe-chain/bin/safe-chain"
cp "$_repo_root/tests/zsh/fixtures/safe-chain-init.zsh" \
  "$_fixture_root/data/safe-chain/scripts/init-posix.sh"

PATH="/usr/bin:/bin"
HOME="$_fixture_root/home"
XDG_DATA_HOME="$_fixture_root/data"
typeset -g _safe_chain_test_mode=recursive
rehash
setopt noerrexit
source "$_repo_root/dot_config/zsh/dot_zshrc.d/02_security.zsh"
typeset -i _source_status=$?
typeset _safe_chain_command_path=${commands[safe-chain]-}
setopt errexit
assert_equal 0 "$_source_status" 'loads the security configuration'
assert_equal 1 "${+functions[npm]}" 'defines a lazy safe-chain wrapper'
assert_equal 0 "${+functions[wrapSafeChainCommand]}" 'does not source safe-chain during startup'
assert_equal "$_fixture_root/data/safe-chain/bin/safe-chain" "$_safe_chain_command_path" \
  'exposes the safe-chain executable during startup'

setopt noerrexit
(
  unsetopt FUNCTION_ARGZERO
  _safe_chain_load() {
    [[ $1 == npm ]]
  }
  npm
)
typeset -i _safe_chain_function_name_status=$?
setopt errexit
assert_equal 0 "$_safe_chain_function_name_status" \
  'resolves the stub command without FUNCTION_ARGZERO'

setopt noerrexit
npm install example 2>/dev/null
typeset -i _safe_chain_recursive_status=$?
setopt errexit
assert_equal 1 "$_safe_chain_recursive_status" 'rejects recursive initialization'
assert_equal 0 "${+parameters[_safe_chain_loading]}" 'unwinds the recursion guard after failure'
assert_equal 1 "${+functions[npm]}" 'restores lazy wrappers after recursive initialization'

typeset -g _safe_chain_test_mode=failure
setopt noerrexit
npm install example 2>/dev/null
typeset -i _safe_chain_failure_status=$?
setopt errexit
assert_equal 1 "$_safe_chain_failure_status" 'normalizes the init failure status'
assert_equal 1 "${+functions[npm]}" 'restores lazy wrappers after an init failure'

mv "$_fixture_root/data/safe-chain/scripts/init-posix.sh" \
  "$_fixture_root/data/safe-chain/scripts/init-posix.sh.away"
setopt noerrexit
npm install example 2> "$_fixture_root/safe-chain-error"
typeset -i _safe_chain_unreadable_status=$?
setopt errexit
typeset _safe_chain_error=${$(<"$_fixture_root/safe-chain-error")//$'\n'/ }
typeset -i _safe_chain_error_is_actionable=0
[[ $_safe_chain_error == *'restore safe-chain or restart the shell'* ]] &&
  _safe_chain_error_is_actionable=1
assert_equal 1 "$_safe_chain_unreadable_status" 'normalizes a missing init file to status 1'
assert_equal 1 "$_safe_chain_error_is_actionable" \
  'explains how to recover from a missing init file'
mv "$_fixture_root/data/safe-chain/scripts/init-posix.sh.away" \
  "$_fixture_root/data/safe-chain/scripts/init-posix.sh"

typeset -g _safe_chain_test_mode=missing
setopt noerrexit
npm install example 2>/dev/null
typeset -i _safe_chain_missing_status=$?
setopt errexit
assert_equal 1 "$_safe_chain_missing_status" 'rejects an incomplete wrapper set'
assert_equal 1 "${+functions[pdm]}" 'keeps missing wrappers protected for a retry'

typeset -g _safe_chain_test_mode=complete
npm --version
assert_equal 'npm:--version' "$_safe_chain_test_call" 'loads safe-chain and forwards arguments'
assert_equal 1 "${+functions[wrapSafeChainCommand]}" 'loads the safe-chain integration once'
assert_equal 0 "${+functions[_safe_chain_load]}" 'removes the loader after initialization'
assert_equal 0 "${+functions[_safe_chain_define_stubs]}" 'removes the stub factory after initialization'
assert_equal 0 "${+functions[_safe_chain_fail]}" 'removes the failure handler after initialization'
assert_equal 0 "${+parameters[_safe_chain_commands]}" 'removes lazy-loader state after initialization'
assert_equal 0 "${+parameters[_safe_chain_stub]}" 'removes the shared stub body after initialization'
