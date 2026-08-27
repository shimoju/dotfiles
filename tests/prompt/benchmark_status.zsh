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
typeset _baseline_output _candidate_output _output
typeset -F _started _elapsed

repeat 5; do
  _benchmark_baseline_status 1 "$_fixture_root" >/dev/null
  _benchmark_candidate_status 1 "$_fixture_root" >/dev/null
done

_benchmark_measure() {
  local function_name=$1

  _started=$EPOCHREALTIME
  _output=$("$function_name" 1 "$_fixture_root")
  _elapsed=$(( (EPOCHREALTIME - _started) * 1000 ))
}

for (( _index = 1; _index <= _sample_count; ++_index )); do
  if (( _index % 2 )); then
    _benchmark_measure _benchmark_baseline_status
    _baseline_times+=($_elapsed)
    _baseline_output=$_output
    _benchmark_measure _benchmark_candidate_status
    _candidate_times+=($_elapsed)
    _candidate_output=$_output
  else
    _benchmark_measure _benchmark_candidate_status
    _candidate_times+=($_elapsed)
    _candidate_output=$_output
    _benchmark_measure _benchmark_baseline_status
    _baseline_times+=($_elapsed)
    _baseline_output=$_output
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
  local -i count=${#samples} p95_index
  local -F total=0 median mean
  local sample

  p95_index=$(( (count * 95 + 99) / 100 ))
  sorted=(${(on)samples})
  for sample in $samples; do
    (( total += sample ))
  done
  mean=$(( total / count ))
  if (( count % 2 )); then
    median=$sorted[$(( (count + 1) / 2 ))]
  else
    median=$(( (sorted[count / 2] + sorted[count / 2 + 1]) / 2 ))
  fi
  printf '%-9s n=%d median=%.3f mean=%.3f min=%.3f p95=%.3f max=%.3f ms\n' \
    "$label" $count $median $mean \
    "${sorted[1]}" "${sorted[$p95_index]}" "${sorted[-1]}"
}

print -r -- "baseline=${_baseline_ref} candidate=worktree records=${_record_count}"
_benchmark_summary baseline "${_baseline_times[@]}"
_benchmark_summary candidate "${_candidate_times[@]}"
