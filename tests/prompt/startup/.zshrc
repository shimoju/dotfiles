emulate -R zsh

setopt prompt_percent prompt_sp prompt_cr
unsetopt beep

zmodload zsh/datetime

for _prompt_bench_required in \
  PROMPT_BENCH_VARIANT \
  PROMPT_BENCH_WORKDIR \
  PROMPT_BENCH_SHSH_SETUP \
  PROMPT_BENCH_ASYNC_PATH \
  PROMPT_BENCH_PURE_ROOT \
  PROMPT_BENCH_TYPEWRITTEN_ROOT \
  PROMPT_BENCH_P10K_ROOT; do
  [[ -n ${(P)_prompt_bench_required-} ]] || {
    print -u2 -r -- "missing $_prompt_bench_required"
    exit 70
  }
done
unset _prompt_bench_required

builtin cd -q -- "$PROMPT_BENCH_WORKDIR" || exit 71

_prompt_bench_emit() {
  builtin print -rn -- $'\e]1337;PROMPT_BENCH_'$1$'\a'
}

_prompt_bench_precmd() {
  (( ${_prompt_bench_ready_emitted:-0} )) && return
  typeset -g _prompt_bench_ready_emitted=1
  PROMPT+=$'%{\e]1337;PROMPT_BENCH_READY\a%}'
}

case $PROMPT_BENCH_VARIANT in
  bare_a|bare_b)
    PROMPT=$'%F{blue}%~%f\n%F{green}❯%f '
    ;;

  bare_direct)
    PROMPT=$'%F{blue}%~%f\n%F{green}❯%f %{\e]1337;PROMPT_BENCH_READY\a%}'
    typeset -g _prompt_bench_ready_emitted=1
    ;;

  shsh)
    source "$PROMPT_BENCH_ASYNC_PATH"
    fpath=("${PROMPT_BENCH_SHSH_SETUP:h}" $fpath)
    autoload -Uz promptinit
    promptinit
    prompt shsh

    # Network work is outside the local startup benchmark.
    _shsh_maybe_fetch() { return 0 }

    functions[_prompt_bench_shsh_callback]=$functions[_shsh_async_callback]
    _shsh_async_callback() {
      local job=$1 result
      _prompt_bench_shsh_callback "$@"
      result=$?
      [[ $job == _shsh_async_git_status ]] && _prompt_bench_emit STATUS
      return result
    }
    ;;

  pure)
    typeset -g PURE_GIT_PULL=0
    zstyle :prompt:pure:environment:nix-shell show no
    zstyle :prompt:pure:environment:virtualenv show no
    zstyle :prompt:pure:git:dirty detailed yes
    zstyle :prompt:pure:git:stash show yes
    fpath=("$PROMPT_BENCH_PURE_ROOT" $fpath)
    autoload -Uz promptinit
    promptinit
    prompt pure

    functions[_prompt_bench_pure_callback]=$functions[prompt_pure_async_callback]
    prompt_pure_async_callback() {
      local job=$1 result
      _prompt_bench_pure_callback "$@"
      result=$?
      [[ $job == prompt_pure_async_git_dirty ]] && _prompt_bench_emit STATUS
      return result
    }
    ;;

  typewritten)
    typeset -g TYPEWRITTEN_PROMPT_LAYOUT=pure
    typeset -g TYPEWRITTEN_CURSOR=terminal
    typeset -g TYPEWRITTEN_DISABLE_RETURN_CODE=true
    source "$PROMPT_BENCH_TYPEWRITTEN_ROOT/typewritten.plugin.zsh"

    functions[_prompt_bench_typewritten_callback]=$functions[tw_prompt_callback]
    tw_prompt_callback() {
      local job=$1 result
      _prompt_bench_typewritten_callback "$@"
      result=$?
      [[ $job == tw_git_status ]] && _prompt_bench_emit STATUS
      return result
    }
    ;;

  p10k)
    source "$PROMPT_BENCH_P10K_ROOT/powerlevel10k.zsh-theme"
    source "$PROMPT_BENCH_P10K_ROOT/config/p10k-lean.zsh"
    typeset -ga POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(dir vcs newline prompt_char)
    typeset -ga POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=()
    typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=false
    typeset -g POWERLEVEL9K_MODE=ascii
    ;;

  *)
    print -u2 -r -- "unknown variant: $PROMPT_BENCH_VARIANT"
    exit 72
    ;;
esac

autoload -Uz add-zsh-hook
[[ $PROMPT_BENCH_VARIANT == bare_direct ]] || \
  add-zsh-hook precmd _prompt_bench_precmd

unset _prompt_bench_ready_emitted
