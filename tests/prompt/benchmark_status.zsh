#!/usr/bin/env zsh

emulate -R zsh
setopt errexit nounset pipefail

zmodload zsh/datetime

export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_NOSYSTEM=1
export TERM=dumb

typeset _repo_root=${0:A:h:h:h}
typeset _prompt_path=dot_config/zsh/prompt/prompt_shsh_setup
typeset _baseline_ref=${1:-HEAD}
typeset -i _sample_count=${2:-50} _record_count=${3:-5500} _index

if (( _sample_count < 1 || _record_count < 1 )); then
  print -u2 -r -- 'sample and record counts must both be positive'
  exit 2
fi

typeset _fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/prompt-shsh-status-benchmark.XXXXXXXX")
_fixture_root=${_fixture_root:A}

cleanup() {
  rm -rf -- "$_fixture_root"
}
trap cleanup EXIT

command git -C "$_fixture_root" init -q -b main
command git -C "$_fixture_root" config user.name benchmark
command git -C "$_fixture_root" config user.email benchmark@example.com
for (( _index = 1; _index <= _record_count; ++_index )); do
  print -r -- base > "$_fixture_root/file-$_index"
done
command git -C "$_fixture_root" add .
command git -C "$_fixture_root" commit -qm base
command git -C "$_fixture_root" ls-files -z |
  command git -C "$_fixture_root" update-index --chmod=+x -z --stdin

source <(command git -C "$_repo_root" show "${_baseline_ref}:${_prompt_path}")
functions[_benchmark_baseline_status]=$functions[_shsh_async_git_status]
source "$_repo_root/$_prompt_path"
functions[_benchmark_candidate_status]=$functions[_shsh_async_git_status]
add-zsh-hook -d precmd _shsh_precmd
add-zsh-hook -d preexec _shsh_preexec

typeset -a _baseline_times=() _candidate_times=()
typeset _baseline_output _candidate_output

repeat 5; do
  _benchmark_baseline_status 1 "$_fixture_root" >/dev/null
  _benchmark_candidate_status 1 "$_fixture_root" >/dev/null
done

# Samples stay integer microseconds because the (on) sort flag compares each
# run of digits on its own, which misorders decimals such as 5.4 against 5.18.
_benchmark_record() {
  local variant=$1
  local -F started=$EPOCHREALTIME
  local output
  local -i elapsed

  output=$("_benchmark_${variant}_status" 1 "$_fixture_root")
  elapsed=$(( (EPOCHREALTIME - started) * 1000000 ))
  if [[ $variant == baseline ]]; then
    _baseline_times+=($elapsed)
    _baseline_output=$output
  else
    _candidate_times+=($elapsed)
    _candidate_output=$output
  fi
}

for (( _index = 1; _index <= _sample_count; ++_index )); do
  # Alternate which variant runs first so drift is shared between them.
  if (( _index % 2 )); then
    _benchmark_record baseline
    _benchmark_record candidate
  else
    _benchmark_record candidate
    _benchmark_record baseline
  fi
  if [[ $_baseline_output != $_candidate_output ]]; then
    print -u2 -r -- 'benchmark outputs differ'
    print -u2 -r -- "  baseline: ${(qqq)_baseline_output}"
    print -u2 -r -- "  candidate: ${(qqq)_candidate_output}"
    exit 1
  fi
done

_benchmark_summary() {
  local label=$1
  shift
  local -a samples=("$@") sorted
  local -i count=${#samples} p95_index median mean low high

  p95_index=$(( (count * 95 + 99) / 100 ))
  low=$(( (count + 1) / 2 ))
  high=$(( (count + 2) / 2 ))
  sorted=(${(on)samples})
  mean=$(( (${(j:+:)samples}) / count ))
  median=$(( (sorted[low] + sorted[high]) / 2 ))
  printf '%-9s n=%d median=%.3f mean=%.3f min=%.3f p95=%.3f max=%.3f ms\n' \
    "$label" $count $(( median / 1000. )) $(( mean / 1000. )) \
    $(( sorted[1] / 1000. )) $(( sorted[p95_index] / 1000. )) \
    $(( sorted[-1] / 1000. ))
}

print -r -- "baseline=${_baseline_ref} candidate=worktree records=${_record_count}"
_benchmark_summary baseline "${_baseline_times[@]}"
_benchmark_summary candidate "${_candidate_times[@]}"
