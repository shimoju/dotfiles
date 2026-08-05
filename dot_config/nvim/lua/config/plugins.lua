vim.pack.add({
  { src = "https://github.com/ibhagwan/fzf-lua" },
  { src = "https://github.com/lewis6991/gitsigns.nvim" },
}, { load = true })

require("plugins.fzf")
require("plugins.gitsigns")
