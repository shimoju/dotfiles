local trouble = require("config.trouble")

local function toggle(mode)
  return function()
    trouble.toggle(mode)
  end
end

vim.keymap.set("n", "<leader>xx", toggle("diagnostics"), {
  desc = "Toggle workspace diagnostics",
})
vim.keymap.set("n", "<leader>xb", toggle({ mode = "diagnostics", filter = { buf = 0 } }), {
  desc = "Toggle buffer diagnostics",
})
vim.keymap.set("n", "<leader>xs", toggle({ mode = "symbols", focus = false }), {
  desc = "Toggle document symbols",
})
vim.keymap.set("n", "<leader>xl", toggle({
  mode = "lsp",
  focus = false,
  win = { position = "right" },
}), { desc = "Toggle LSP locations" })
vim.keymap.set("n", "<leader>xq", toggle("qflist"), {
  desc = "Toggle quickfix list",
})
