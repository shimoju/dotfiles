local dap = require("dap")
local dapui = require("dapui")

require("dap-ruby").setup()
dapui.setup()

vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DapBreakpoint" })
vim.fn.sign_define("DapBreakpointCondition", { text = "●", texthl = "DapBreakpointCondition" })
vim.fn.sign_define("DapBreakpointRejected", { text = "●", texthl = "DapBreakpointRejected" })
vim.fn.sign_define("DapLogPoint", { text = "◆", texthl = "DapLogPoint" })
vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DapStopped", numhl = "DapStopped" })

dap.listeners.before.attach.dapui = function()
  dapui.open()
end
dap.listeners.before.launch.dapui = function()
  dapui.open()
end
dap.listeners.before.event_terminated.dapui = function()
  dapui.close()
end
dap.listeners.before.event_exited.dapui = function()
  dapui.close()
end

dap.adapters["pwa-node"] = function(callback)
  vim.system({ "mise", "where", "github:microsoft/vscode-js-debug" }, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        vim.notify("vscode-js-debug is not installed by mise", vim.log.levels.ERROR)
        return
      end

      local server = vim.fs.joinpath(vim.trim(result.stdout), "src", "dapDebugServer.js")
      callback({
        type = "server",
        host = "127.0.0.1",
        port = "${port}",
        executable = {
          command = "node",
          args = { server, "${port}" },
        },
      })
    end)
  end)
end

local function find_vitest()
  local current_file = vim.api.nvim_buf_get_name(0)
  for directory in vim.fs.parents(current_file) do
    local candidate = vim.fs.joinpath(directory, "node_modules", "vitest", "vitest.mjs")
    if vim.uv.fs_stat(candidate) then
      return candidate
    end
  end

  error("node_modules/vitest/vitest.mjs was not found")
end

local javascript_configurations = {
  {
    type = "pwa-node",
    request = "launch",
    name = "Launch current file",
    program = "${file}",
    cwd = "${workspaceFolder}",
    sourceMaps = true,
    console = "integratedTerminal",
    skipFiles = { "<node_internals>/**", "**/node_modules/**" },
  },
  {
    type = "pwa-node",
    request = "launch",
    name = "Debug current Vitest file",
    program = find_vitest,
    args = function()
      return { "run", vim.api.nvim_buf_get_name(0), "--no-file-parallelism", "--test-timeout=0" }
    end,
    cwd = function()
      local vitest = find_vitest()
      return vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(vitest)))
    end,
    autoAttachChildProcesses = true,
    smartStep = true,
    console = "integratedTerminal",
    skipFiles = { "<node_internals>/**", "**/node_modules/**" },
  },
  {
    type = "pwa-node",
    request = "attach",
    name = "Attach to Node process",
    processId = require("dap.utils").pick_process,
    cwd = "${workspaceFolder}",
    sourceMaps = true,
  },
}

for _, filetype in ipairs({ "javascript", "javascriptreact", "typescript", "typescriptreact" }) do
  dap.configurations[filetype] = vim.deepcopy(javascript_configurations)
end

local function map(lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { desc = desc })
end

map("<F5>", dap.continue, "Debug continue")
map("<F10>", dap.step_over, "Debug step over")
map("<F11>", dap.step_into, "Debug step into")
map("<F12>", dap.step_out, "Debug step out")
map("<leader>db", dap.toggle_breakpoint, "Debug breakpoint")
map("<leader>dB", function()
  dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
end, "Debug conditional breakpoint")
map("<leader>dc", dap.continue, "Debug continue")
map("<leader>dl", dap.run_last, "Debug last")
map("<leader>dr", dap.repl.toggle, "Debug REPL")
map("<leader>dt", dap.terminate, "Debug terminate")
map("<leader>du", dapui.toggle, "Debug UI")
