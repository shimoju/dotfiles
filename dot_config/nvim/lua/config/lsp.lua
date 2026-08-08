local formatter_by_filetype = {
  javascript = "vtsls",
  javascriptreact = "vtsls",
  ruby = "ruby_lsp",
  rust = "rust-analyzer",
  typescript = "vtsls",
  typescriptreact = "vtsls",
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

vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("config-lsp-format", { clear = true }),
  callback = function(args)
    format(args.buf)
  end,
})

vim.keymap.set("n", "<leader>lf", function()
  format(0)
end, { desc = "Format LSP buffer" })

vim.lsp.config("*", {
  capabilities = require("blink.cmp").get_lsp_capabilities(),
})

vim.lsp.enable({ "ruby_lsp", "vtsls" })
