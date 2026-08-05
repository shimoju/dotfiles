require("gitsigns").setup({
  on_attach = function(bufnr)
    local gitsigns = require("gitsigns")

    local function map(lhs, rhs, desc)
      vim.keymap.set("n", lhs, rhs, { buffer = bufnr, desc = desc })
    end

    map("]c", function()
      if vim.wo.diff then
        vim.cmd.normal({ "]c", bang = true })
      else
        gitsigns.nav_hunk("next")
      end
    end, "Next Git hunk")

    map("[c", function()
      if vim.wo.diff then
        vim.cmd.normal({ "[c", bang = true })
      else
        gitsigns.nav_hunk("prev")
      end
    end, "Previous Git hunk")

    map("<leader>gp", gitsigns.preview_hunk, "Preview Git hunk")
    map("<leader>gb", function()
      gitsigns.blame_line({ full = true })
    end, "Blame Git line")
    map("<leader>gd", gitsigns.diffthis, "Diff Git buffer")
  end,
})
