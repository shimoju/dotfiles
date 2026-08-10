local function config()
  return require("config.dap")
end

local function map(lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { desc = desc })
end

vim.api.nvim_create_autocmd("CmdUndefined", {
  group = vim.api.nvim_create_augroup("config-lazy-dap-command", { clear = true }),
  pattern = "Dap*",
  once = true,
  callback = function()
    config()
  end,
})

map("<F5>", function()
  config().dap.continue()
end, "Debug continue")
map("<F10>", function()
  config().dap.step_over()
end, "Debug step over")
map("<F11>", function()
  config().dap.step_into()
end, "Debug step into")
map("<F12>", function()
  config().dap.step_out()
end, "Debug step out")
map("<leader>db", function()
  config().dap.toggle_breakpoint()
end, "Debug breakpoint")
map("<leader>dB", function()
  config().dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
end, "Debug conditional breakpoint")
map("<leader>dc", function()
  config().dap.continue()
end, "Debug continue")
map("<leader>dl", function()
  config().dap.run_last()
end, "Debug last")
map("<leader>dr", function()
  config().dap.repl.toggle()
end, "Debug REPL")
map("<leader>dt", function()
  config().dap.terminate()
end, "Debug terminate")
map("<leader>du", function()
  config().dapui.toggle()
end, "Debug UI")
