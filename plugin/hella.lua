-- hella.nvim plugin entry point
-- Loaded automatically by Neovim when the plugin is in runtimepath

if vim.g.hella_loaded then
  return
end
vim.g.hella_loaded = true

-- Auto-start LSP when a Hella file is opened
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'hella',
  group = vim.api.nvim_create_augroup('hella-lsp-start', { clear = true }),
  callback = function()
    local ok, hella = pcall(require, 'hella')
    if ok and type(hella.start) == 'function' then
      hella.start()
    end
  end,
})

-- Canonical formatter (`hella fmt` via the CLI). Defined here so the
-- commands exist even when the user never calls require("hella").setup().
vim.api.nvim_create_user_command('HellaFormat', function()
  require('hella').format()
end, { desc = 'Format current Hella buffer with hella fmt' })

vim.api.nvim_create_user_command('HellaFormatCheck', function()
  require('hella').format_check()
end, { desc = 'Check current Hella buffer with hella fmt --check' })
