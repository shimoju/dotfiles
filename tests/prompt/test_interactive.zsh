#!/usr/bin/env zsh

emulate -R zsh
setopt errexit pipefail

typeset _fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/prompt-shsh-interactive.XXXXXXXX")
typeset _test_zdotdir=$(mktemp -d "${TMPDIR:-/tmp}/prompt-shsh-zdotdir.XXXXXXXX")
trap 'rm -rf -- "$_fixture_root" "$_test_zdotdir"' EXIT

typeset _source_zdotdir=${0:A:h:h:h}/dot_config/zsh
ln -s "${_source_zdotdir}/prompt" "${_test_zdotdir}/prompt"

command git -C "$_fixture_root" init -q -b main
command git -C "$_fixture_root" config user.name 'Prompt Test'
command git -C "$_fixture_root" config user.email prompt@example.invalid
print -r -- tracked > "$_fixture_root/tracked"
command git -C "$_fixture_root" add tracked
command git -C "$_fixture_root" commit -q -m initial

PROMPT_TEST_FIXTURE=$_fixture_root PROMPT_TEST_ZDOTDIR=$_test_zdotdir /usr/bin/expect \
  "${0:A:h}/test_interactive.exp"
