vim.api.nvim_create_autocmd("PackChanged", {
  group = vim.api.nvim_create_augroup("config-pack-hooks", { clear = true }),
  callback = function(args)
    local name = args.data.spec.name
    local kind = args.data.kind

    -- Parser revisions must stay in sync with nvim-treesitter queries.
    if name == "nvim-treesitter" and kind == "update" then
      if not args.data.active then
        vim.cmd.packadd("nvim-treesitter")
      end
      require("nvim-treesitter").update()
    end
  end,
})

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
  {
    src = "https://github.com/nvim-treesitter/nvim-treesitter",
    version = "main",
  },
})
