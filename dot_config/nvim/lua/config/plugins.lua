vim.pack.add({
  { src = "https://github.com/ibhagwan/fzf-lua" },
  { src = "https://github.com/lewis6991/gitsigns.nvim" },
  {
    src = "https://github.com/neovim/nvim-lspconfig",
    version = vim.version.range("^2"),
  },
  {
    src = "https://github.com/Saghen/blink.cmp",
    version = vim.version.range("^1"),
  },
})
