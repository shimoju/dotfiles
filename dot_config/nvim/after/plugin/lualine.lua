local trouble = require("config.trouble")
local symbols = trouble.statusline({
  mode = "lsp_document_symbols",
  groups = {},
  title = false,
  filter = { range = true },
  format = "{kind_icon}{symbol.name:Normal}",
  hl_group = "lualine_c_normal",
})

require("lualine").setup({
  options = { theme = "catppuccin-nvim" },
  sections = {
    lualine_c = {
      "filename",
      { symbols.get, cond = symbols.has },
    },
  },
})
