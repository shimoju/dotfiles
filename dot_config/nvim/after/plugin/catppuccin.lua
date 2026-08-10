require("catppuccin").setup({
  flavour = "mocha",
  default_integrations = false,
  integrations = {
    blink_cmp = { enabled = true, style = "bordered" },
    dap = true,
    dap_ui = true,
    fidget = true,
    fzf = true,
    gitsigns = true,
    indent_blankline = {
      enabled = true,
      scope_color = "",
      colored_indent_levels = false,
    },
    lsp_trouble = true,
    neotest = true,
    nvim_surround = true,
    nvimtree = true,
    which_key = true,
  },
})

vim.cmd.colorscheme("catppuccin-mocha")
