# safe-chain
_safe_chain_root="${XDG_DATA_HOME:-$HOME/.local/share}/safe-chain"
_safe_chain_init="$_safe_chain_root/scripts/init-posix.sh"
if [[ -r "$_safe_chain_init" ]]; then
  # Keep this list in sync with init-posix.sh when updating safe-chain.
  typeset -ga _safe_chain_commands=(
    npx yarn pnpm pnpx rush rushx bun bunx npm
    pip pip3 uv uvx poetry python python3 pipx pdm
  )

  # One body for every stub, which also marks a command as still unreplaced by
  # the upstream wrapper.
  _safe_chain_stub='_safe_chain_load "${funcstack[1]}" "$@"'

  # init-posix.sh appends this path after resolving it with external commands.
  # Expose safe-chain immediately and defer the rest of the init work.
  path+=("$_safe_chain_root/bin"(N))

  _safe_chain_define_stubs() {
    local _safe_chain_command
    for _safe_chain_command in $_safe_chain_commands; do
      functions[$_safe_chain_command]=$_safe_chain_stub
    done
  }

  _safe_chain_fail() {
    _safe_chain_define_stubs
    print -u2 -r -- "safe-chain: $1"
    return 1
  }

  _safe_chain_load() {
    local _safe_chain_command=$1 _safe_chain_expected _safe_chain_status
    shift

    if (( ${_safe_chain_loading:-0} )); then
      print -u2 -r -- 'safe-chain: recursive initialization detected'
      return 1
    fi

    if [[ ! -r "$_safe_chain_init" ]]; then
      _safe_chain_fail \
        "init is no longer readable: $_safe_chain_init; restore safe-chain or restart the shell to remove its command guards"
      return
    fi

    local _safe_chain_loading=1
    builtin source "$_safe_chain_init"
    _safe_chain_status=$?

    if (( _safe_chain_status != 0 )); then
      _safe_chain_fail \
        "failed to load $_safe_chain_init (status $_safe_chain_status); restore safe-chain or restart the shell to remove its command guards"
      return
    fi

    for _safe_chain_expected in $_safe_chain_commands; do
      if (( ! ${+functions[$_safe_chain_expected]} )) ||
          [[ ${functions[$_safe_chain_expected]} == *"$_safe_chain_stub"* ]]; then
        _safe_chain_fail \
          "init did not define expected wrapper: $_safe_chain_expected"
        return
      fi
    done

    unset _safe_chain_init _safe_chain_commands _safe_chain_stub
    unfunction _safe_chain_define_stubs _safe_chain_fail _safe_chain_load
    "$_safe_chain_command" "$@"
  }

  _safe_chain_define_stubs
else
  unset _safe_chain_init
fi
unset _safe_chain_root
