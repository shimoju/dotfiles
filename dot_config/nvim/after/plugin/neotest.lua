local function neotest()
  return require("config.neotest")
end

local function map(lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { desc = desc })
end

vim.api.nvim_create_autocmd("CmdUndefined", {
  group = vim.api.nvim_create_augroup("config-lazy-neotest-command", { clear = true }),
  pattern = "Neotest",
  once = true,
  callback = function()
    neotest()
  end,
})

map("<leader>tn", function()
  neotest().run.run()
end, "Test nearest")

map("<leader>tf", function()
  neotest().run.run(vim.fn.expand("%"))
end, "Test file")

map("<leader>tl", function()
  neotest().run.run_last()
end, "Test last")
map("<leader>ts", function()
  neotest().summary.toggle()
end, "Test summary")

map("<leader>to", function()
  neotest().output.open({ enter = true })
end, "Test output")

map("<leader>tp", function()
  neotest().output_panel.toggle()
end, "Test output panel")

map("<leader>td", function()
  require("config.dap")
  neotest().run.run({ strategy = "dap" })
end, "Debug nearest test")

map("<leader>tS", function()
  neotest().run.stop()
end, "Stop test")
