local function lldb_dap_adapter()
  local command = vim.fn.exepath("lldb-dap")
  if command ~= "" then
    return {
      type = "executable",
      command = command,
      name = "lldb",
    }
  end

  if vim.fn.has("mac") == 1 and vim.fn.executable("xcrun") == 1 then
    return {
      type = "executable",
      command = vim.fn.exepath("xcrun"),
      args = { "lldb-dap" },
      name = "lldb",
    }
  end

  return false
end

vim.g.rustaceanvim = function()
  local config = {
    server = {
      capabilities = require("blink.cmp").get_lsp_capabilities(),
    },
  }

  config.dap = { adapter = lldb_dap_adapter }

  return config
end
