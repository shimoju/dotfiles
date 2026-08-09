local formatter_by_filetype = {
  javascript = "vtsls",
  javascriptreact = "vtsls",
  ruby = "ruby_lsp",
  rust = "rust-analyzer",
  typescript = "vtsls",
  typescriptreact = "vtsls",
}

local vtsls_inlay_hints = {
  parameterNames = { enabled = "literals" },
  parameterTypes = { enabled = true },
  variableTypes = { enabled = true },
  propertyDeclarationTypes = { enabled = true },
  functionLikeReturnTypes = { enabled = true },
  enumMemberValues = { enabled = true },
}

local function format(bufnr)
  bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr

  local client_name = formatter_by_filetype[vim.bo[bufnr].filetype]
  if not client_name then
    return
  end

  local clients = vim.lsp.get_clients({
    bufnr = bufnr,
    method = "textDocument/formatting",
    name = client_name,
  })
  if #clients == 0 then
    return
  end

  vim.lsp.buf.format({
    bufnr = bufnr,
    name = client_name,
    timeout_ms = 5000,
  })
end

local function toggle_inlay_hints()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({
    bufnr = bufnr,
    method = "textDocument/inlayHint",
  })
  if #clients == 0 then
    vim.notify("Inlay hints are not supported in this buffer", vim.log.levels.WARN)
    return
  end

  local enabled = not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
  vim.lsp.inlay_hint.enable(enabled, { bufnr = bufnr })
  vim.notify("Inlay hints " .. (enabled and "enabled" or "disabled"))
end

vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("config-lsp-format", { clear = true }),
  callback = function(args)
    format(args.buf)
  end,
})

vim.keymap.set("n", "<leader>lf", function()
  format(0)
end, { desc = "Format LSP buffer" })

vim.keymap.set("n", "<leader>lh", toggle_inlay_hints, { desc = "Toggle LSP inlay hints" })

vim.lsp.config("*", {
  capabilities = require("blink.cmp").get_lsp_capabilities(),
})

vim.lsp.config("vtsls", {
  settings = {
    typescript = { inlayHints = vtsls_inlay_hints },
    javascript = { inlayHints = vim.deepcopy(vtsls_inlay_hints) },
  },
})

vim.lsp.enable({ "ruby_lsp", "vtsls" })
