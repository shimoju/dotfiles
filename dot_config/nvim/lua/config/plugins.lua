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
  {
    src = "https://github.com/catppuccin/nvim",
    name = "catppuccin",
    version = vim.version.range("^2"),
  },
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
  { src = "https://github.com/antoinemadec/FixCursorHold.nvim" },
  { src = "https://github.com/nvim-neotest/nvim-nio" },
  { src = "https://github.com/nvim-neotest/neotest" },
  { src = "https://github.com/olimorris/neotest-rspec" },
  { src = "https://github.com/marilari88/neotest-vitest" },
  { src = "https://github.com/mfussenegger/nvim-dap" },
  { src = "https://github.com/rcarriga/nvim-dap-ui" },
  { src = "https://github.com/suketa/nvim-dap-ruby" },
  {
    src = "https://github.com/mrcjkb/rustaceanvim",
    version = vim.version.range("^9"),
  },
})
