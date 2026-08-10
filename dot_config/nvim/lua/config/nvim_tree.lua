require("config.pack").load("nvim-tree.lua")

require("nvim-tree").setup({
  update_focused_file = { enable = true },
})

return require("nvim-tree.api")
