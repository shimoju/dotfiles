local opt = vim.opt

opt.termguicolors = true
opt.number = true
opt.showmatch = true
opt.scrolloff = 4
opt.sidescrolloff = 8
opt.inccommand = "split"
opt.winborder = "rounded"
opt.list = true
opt.listchars = {
  tab = "» ",
  trail = "•",
  nbsp = "␣",
}

opt.ignorecase = true
opt.smartcase = true

opt.expandtab = true
opt.tabstop = 2
opt.shiftwidth = 2
opt.softtabstop = -1

opt.undofile = true
opt.confirm = true
opt.clipboard = "unnamedplus"

opt.splitbelow = true
opt.splitright = true
opt.cursorline = true
opt.signcolumn = "yes"
