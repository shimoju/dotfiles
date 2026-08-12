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
    map("<leader>gi", gitsigns.preview_hunk_inline, "Preview Git hunk inline")
    map("<leader>ga", gitsigns.stage_hunk, "Stage Git hunk")
    vim.keymap.set("x", "<leader>ga", function()
      gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
    end, { buffer = bufnr, desc = "Stage selected Git lines" })
    map("<leader>gA", gitsigns.stage_buffer, "Stage Git buffer")
    map("<leader>gu", gitsigns.reset_buffer_index, "Unstage Git buffer")
    map("<leader>gb", function()
      gitsigns.blame_line({ full = true })
    end, "Blame Git line")
    map("<leader>gd", gitsigns.diffthis, "Diff Git buffer")
  end,
})
