vim.keymap.set("n", "<leader>gg", "<Cmd>Git<CR>", { desc = "Git summary" })
vim.keymap.set("n", "<leader>gd", "<Cmd>Git diff<CR>", { desc = "Git unstaged diff" })
vim.keymap.set("n", "<leader>gD", "<Cmd>Git diff --staged<CR>", { desc = "Git staged diff" })
vim.keymap.set("n", "<leader>gl", "<Cmd>Git log -p<CR>", { desc = "Git log with patches" })
vim.keymap.set("n", "<leader>gc", "<Cmd>Git commit<CR>", { desc = "Git commit" })
vim.keymap.set("n", "<leader>gP", "<Cmd>Git! push<CR>", { desc = "Git push" })

local function current_file_path()
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" or vim.bo.buftype ~= "" then
    vim.notify("Current buffer is not a file", vim.log.levels.WARN)
    return nil
  end
  return path
end

local function copy_path(path, kind)
  vim.fn.setreg("+", path)
  vim.notify("Copied " .. kind .. " path: " .. path)
end

local function git_relative_file_path()
  local path = current_file_path()
  if not path then
    return nil
  end

  local worktree = vim.fn.FugitiveWorkTree()
  if worktree == "" then
    vim.notify("Current file is not in a Git work tree", vim.log.levels.WARN)
    return nil
  end

  return vim.fn["fugitive#Path"](path, "")
end

vim.keymap.set("n", "<leader>yr", function()
  local path = git_relative_file_path()
  if path then
    copy_path(path, "relative")
  end
end, { desc = "Copy Git-relative file path" })

vim.keymap.set("n", "<leader>ya", function()
  local path = current_file_path()
  if path then
    copy_path(vim.fs.abspath(path), "absolute")
  end
end, { desc = "Copy absolute file path" })

vim.keymap.set("n", "<leader>yl", function()
  local path = git_relative_file_path()
  if path then
    copy_path(path .. ":" .. vim.api.nvim_win_get_cursor(0)[1], "relative line")
  end
end, { desc = "Copy Git-relative file path with line" })
