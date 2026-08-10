local M = {}

local deferred = {}
local loaded = {}

function M.defer(plugin)
  deferred[plugin.spec.name] = plugin
end

local function load_one(name)
  if loaded[name] then
    return
  end

  local plugin = deferred[name]
  assert(plugin, ("Deferred plugin %q is not registered"):format(name))

  loaded[name] = true
  local ok, err = xpcall(function()
    vim.cmd.packadd({ name, magic = { file = false } })

    -- :packadd does not source after/plugin files after startup.
    if vim.v.vim_did_enter == 1 then
      local paths = vim.fn.glob(plugin.path .. "/after/plugin/**/*.{vim,lua}", false, true)
      for _, path in ipairs(paths) do
        vim.cmd.source({ path, magic = { file = false } })
      end
    end
  end, debug.traceback)

  if not ok then
    loaded[name] = nil
    error(err, 0)
  end
end

function M.load(names)
  if type(names) == "string" then
    names = { names }
  end

  for _, name in ipairs(names) do
    load_one(name)
  end
end

return M
