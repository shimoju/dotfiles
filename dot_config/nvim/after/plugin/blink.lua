require("blink.cmp").setup({
  keymap = { preset = "super-tab" },
  completion = {
    documentation = {
      auto_show = true,
      auto_show_delay_ms = 500,
    },
    ghost_text = { enabled = false },
  },
  sources = {
    default = { "lsp", "path", "snippets", "buffer" },
  },
  signature = { enabled = true },
  fuzzy = { implementation = "prefer_rust" },
})
