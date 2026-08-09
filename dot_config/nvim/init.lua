vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

require("config.options")
require("config.keymaps")
-- The Neotest adapter reads this global config as soon as plugins load.
require("config.rustaceanvim")
require("config.plugins")
require("config.lsp")
