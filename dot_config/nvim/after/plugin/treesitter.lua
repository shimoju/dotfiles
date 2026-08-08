local parsers = {
  "bash",
  "css",
  "embedded_template",
  "html",
  "javascript",
  "json",
  "lua",
  "markdown",
  "markdown_inline",
  "query",
  "regex",
  "ruby",
  "rust",
  "toml",
  "tsx",
  "typescript",
  "vim",
  "vimdoc",
  "yaml",
  "zsh",
}

require("nvim-treesitter").install(parsers)

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("config-treesitter", { clear = true }),
  callback = function(args)
    local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
    if lang and vim.treesitter.language.add(lang) then
      vim.treesitter.start(args.buf, lang)
    end
  end,
})
