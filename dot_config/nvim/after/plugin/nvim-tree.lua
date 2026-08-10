vim.api.nvim_create_autocmd("CmdUndefined", {
  group = vim.api.nvim_create_augroup("config-lazy-nvim-tree-command", { clear = true }),
  pattern = "NvimTree*",
  once = true,
  callback = function()
    require("config.nvim_tree")
  end,
})

vim.keymap.set("n", "<leader>e", function()
  require("config.nvim_tree").tree.toggle({ find_file = true, focus = true })
end, { desc = "Explorer" })
