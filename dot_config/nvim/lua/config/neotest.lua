require("config.pack").load({
  "nvim-nio",
  "FixCursorHold.nvim",
  "neotest",
  "neotest-rspec",
  "neotest-vitest",
})

local neotest = require("neotest")

neotest.setup({
  adapters = {
    require("neotest-rspec"),
    require("neotest-vitest"),
    require("rustaceanvim.neotest"),
  },
})

return neotest
