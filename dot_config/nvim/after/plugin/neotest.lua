local neotest = require("neotest")

neotest.setup({
  adapters = {
    require("neotest-rspec"),
    require("neotest-vitest"),
    require("rustaceanvim.neotest"),
  },
})

local function map(lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { desc = desc })
end

map("<leader>tn", function()
  neotest.run.run()
end, "Test nearest")

map("<leader>tf", function()
  neotest.run.run(vim.fn.expand("%"))
end, "Test file")

map("<leader>tl", neotest.run.run_last, "Test last")
map("<leader>ts", neotest.summary.toggle, "Test summary")

map("<leader>to", function()
  neotest.output.open({ enter = true })
end, "Test output")

map("<leader>tp", neotest.output_panel.toggle, "Test output panel")

map("<leader>td", function()
  neotest.run.run({ strategy = "dap" })
end, "Debug nearest test")

map("<leader>tS", neotest.run.stop, "Stop test")
