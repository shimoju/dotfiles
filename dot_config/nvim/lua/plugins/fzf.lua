local fzf = require("fzf-lua")

vim.keymap.set("n", "<leader>ff", fzf.files, { desc = "Find files" })
vim.keymap.set("n", "<leader>fg", fzf.live_grep, { desc = "Live grep" })
vim.keymap.set("n", "<leader>fb", fzf.buffers, { desc = "Find buffers" })
vim.keymap.set("n", "<leader>fh", fzf.helptags, { desc = "Find help" })
vim.keymap.set("n", "<leader>gs", fzf.git_status, { desc = "Git status" })
