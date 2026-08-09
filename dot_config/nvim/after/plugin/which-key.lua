local which_key = require("which-key")

which_key.setup({ preset = "modern" })
which_key.add({
  { "<leader>d", group = "debug" },
  { "<leader>f", group = "find" },
  { "<leader>g", group = "git" },
  { "<leader>l", group = "LSP" },
  { "<leader>t", group = "test" },
  { "<leader>x", group = "problems" },
})
