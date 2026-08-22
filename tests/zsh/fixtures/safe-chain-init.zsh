if [[ $_safe_chain_test_mode == failure ]]; then
  return 23
fi

if [[ $_safe_chain_test_mode == recursive ]]; then
  npm nested
  return $?
fi

typeset -a _safe_chain_test_upstream_commands=(
  npx yarn pnpm pnpx rush rushx bun bunx npm
  pip pip3 uv uvx poetry python python3 pipx pdm
)

wrapSafeChainCommand() { :; }

for _safe_chain_test_command in $_safe_chain_test_upstream_commands; do
  if [[ $_safe_chain_test_mode == missing && $_safe_chain_test_command == pdm ]]; then
    continue
  fi
  eval "${_safe_chain_test_command}() { typeset -g _safe_chain_test_call=${(q)_safe_chain_test_command}:\"\$*\"; }"
done

unset _safe_chain_test_command _safe_chain_test_upstream_commands
