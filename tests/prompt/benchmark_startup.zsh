#!/usr/bin/env zsh

emulate -LR zsh
setopt errexit nounset pipefail

if (( $# < 2 || $# > 4 )); then
  print -u2 -r -- \
    "usage: $0 <clean-git-repository> <output-directory> [samples] [warmups]"
  exit 64
fi

typeset -r _repo=${1:A}
typeset -r _output=${2:A}
typeset -ri _samples=${3:-50}
typeset -ri _warmups=${4:-5}
typeset -r _project_root=${0:A:h:h:h}
typeset -r _events=$_output/events.tsv
typeset -r _terminal_log=$_output/terminal.tty
typeset -r _summary=$_output/summary.tsv
typeset -a _variants

if [[ -n ${PROMPT_BENCH_VARIANTS:-} ]]; then
  _variants=(${=PROMPT_BENCH_VARIANTS})
else
  _variants=(bare_a bare_b bare_direct shsh pure typewritten p10k)
fi

typeset -a _required=(
  PROMPT_BENCH_ASYNC_PATH
  PROMPT_BENCH_PURE_ROOT
  PROMPT_BENCH_TYPEWRITTEN_ROOT
  PROMPT_BENCH_P10K_ROOT
  PROMPT_BENCH_GITSTATUS_CACHE
)
typeset _name
for _name in $_required; do
  [[ -n ${(P)_name-} ]] || {
    print -u2 -r -- "missing environment variable: $_name"
    exit 65
  }
done

[[ -d $_repo/.git ]] || {
  print -u2 -r -- "not a Git worktree: $_repo"
  exit 66
}
if [[ ${PROMPT_BENCH_ALLOW_DIRTY:-0} != 1 ]]; then
  [[ -z $(command git -C $_repo status --porcelain=v2) ]] || {
    print -u2 -r -- "benchmark repository is not clean: $_repo"
    exit 67
  }
fi
[[ $(command git -C $_repo symbolic-ref --short HEAD) == prompt-benchmark ]] || {
  print -u2 -r -- "benchmark branch must be named prompt-benchmark"
  exit 68
}
[[ ! -e $_output ]] || {
  print -u2 -r -- "output path already exists: $_output"
  exit 69
}

command mkdir -p -- $_output/nonrepo $_output/cache
print -r -- $'variant\tcondition\titeration\tstartup_ms\tinput_ms\tbranch_ms\tstatus_ms\toutcome' >$_events
: >$_terminal_log

export PROMPT_BENCH_EVENTS=$_events
export PROMPT_BENCH_TERMINAL_LOG=$_terminal_log
export PROMPT_BENCH_SAMPLES=$_samples
export PROMPT_BENCH_WARMUPS=$_warmups
export PROMPT_BENCH_NONREPO=$_output/nonrepo
export PROMPT_BENCH_REPO=$_repo
export PROMPT_BENCH_ZDOTDIR=$_project_root/tests/prompt/startup
export PROMPT_BENCH_ZSH=/bin/zsh
export PROMPT_BENCH_SHSH_SETUP=$_project_root/dot_config/zsh/prompt/prompt_shsh_setup
export PROMPT_BENCH_XDG_CACHE=$_output/cache

command /usr/bin/expect $_project_root/tests/prompt/benchmark_startup.exp

print -r -- $'variant\tcondition\tmetric\tn\tmedian_ms\tmean_ms\tmin_ms\tp95_ms\tmax_ms\ttimeouts' >$_summary

_prompt_bench_summarize() {
  local variant=$1 condition=$2 metric=$3 column=$4
  local -a values
  local raw value outcome
  local -a fields
  local -F sum=0 median mean minimum p95 maximum
  local -i n index timeouts=0

  while IFS= read -r raw; do
    fields=("${(@ps:\t:)raw}")
    [[ $fields[1] == $variant && $fields[2] == $condition ]] || continue
    outcome=$fields[8]
    value=$fields[$column]
    if [[ $outcome == ok && -n $value ]]; then
      values+=($value)
    else
      (( ++timeouts ))
    fi
  done <$_events

  values=(${(on)values})
  n=$#values
  if (( n == 0 )); then
    print -r -- "$variant\t$condition\t$metric\t0\t\t\t\t\t\t$timeouts" >>$_summary
    return
  fi

  for value in $values; do
    (( sum += value ))
  done
  minimum=$values[1]
  maximum=$values[-1]
  mean=$(( sum / n ))
  if (( n % 2 )); then
    median=$values[$(( (n + 1) / 2 ))]
  else
    median=$(( (values[n / 2] + values[n / 2 + 1]) / 2.0 ))
  fi
  index=$(( (95 * n + 99) / 100 ))
  p95=$values[$index]

  printf '%s\t%s\t%s\t%d\t%.3f\t%.3f\t%.3f\t%.3f\t%.3f\t%d\n' \
    $variant $condition $metric $n $median $mean $minimum $p95 $maximum $timeouts \
    >>$_summary
}

typeset _variant _condition
for _variant in $_variants; do
  for _condition in nonrepo repo; do
    _prompt_bench_summarize $_variant $_condition startup 4
    _prompt_bench_summarize $_variant $_condition input 5
    if [[ $_condition == repo && $_variant != bare* ]]; then
      _prompt_bench_summarize $_variant $_condition branch 6
      _prompt_bench_summarize $_variant $_condition status 7
    fi
  done
done

print -r -- "events: $_events"
print -r -- "summary: $_summary"
print -r -- "terminal: $_terminal_log"
