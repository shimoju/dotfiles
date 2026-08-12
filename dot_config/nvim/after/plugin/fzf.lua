local fzf = require("fzf-lua")
local fzf_config = require("fzf-lua.config")
local trouble_actions = require("trouble.sources.fzf").actions

fzf.register_ui_select()
fzf_config.defaults.actions.files["ctrl-x"] = trouble_actions.open

vim.keymap.set("n", "<leader>ff", fzf.files, { desc = "Find files" })
vim.keymap.set("n", "<leader>fg", fzf.live_grep, { desc = "Live grep" })
vim.keymap.set("n", "<leader>fw", fzf.grep_cword, { desc = "Find word under cursor" })
vim.keymap.set("x", "<leader>fw", fzf.grep_visual, { desc = "Find selected text" })
vim.keymap.set("n", "<leader>fr", fzf.resume, { desc = "Resume last find" })
vim.keymap.set("n", "<leader>fb", fzf.buffers, { desc = "Find buffers" })
vim.keymap.set("n", "<leader>fh", fzf.helptags, { desc = "Find help" })
vim.keymap.set("n", "<leader>gs", fzf.git_status, { desc = "Git status" })
