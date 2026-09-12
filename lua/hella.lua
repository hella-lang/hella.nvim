-- hella.nvim — Hella language support for Neovim
-- Provides syntax highlighting + LSP integration (via the `hella lsp` subcommand)

local M = {}

--- Default configuration
M.defaults = {
  -- Command to start the Hella language server (must speak LSP over stdio)
  cmd = { 'hella', 'lsp' },

  -- Capabilities advertised to the server
  capabilities = vim.lsp.protocol.make_client_capabilities(),

  -- Project root detection: walk up from the current buffer until one of
  -- these files is found.  Falls back to the buffer's directory.
  -- `hella.toml` marks a Hella project root (see `hella new`).
  root_markers = { 'hella.toml', 'Cargo.toml', '.git' },

  -- Automatically start the language server when a Hella buffer is opened
  auto_start = true,

  -- Buffer-local keymaps to set when the client attaches
  -- Set to false to disable entirely, or provide your own table
  -- NOTE: `<leader>f` runs `hella fmt` (the canonical CLI formatter),
  -- not LSP formatting: the language server does not advertise
  -- `documentFormattingProvider` (see references/toolchain.md / the
  -- `formatter` skill — editor/LSP integration is still a future
  -- extension, so formatting goes through the CLI).
  keymaps = {
    ['<leader>gd'] = function() vim.lsp.buf.definition() end,
    ['<leader>gr'] = function() vim.lsp.buf.references() end,
    ['<leader>gD'] = function() vim.lsp.buf.type_definition() end,
    ['<leader>gi'] = function() vim.lsp.buf.implementation() end,
    ['<leader>rn'] = function() vim.lsp.buf.rename() end,
    ['<leader>ca'] = function() vim.lsp.buf.code_action() end,
    ['K']          = function() vim.lsp.buf.hover() end,
    ['<leader>f']  = function() require('hella').format() end,
  },

  -- Canonical formatter (`hella fmt [paths...] [--check]`).
  -- `cmd = nil` derives the command from the LSP `cmd` above by
  -- swapping the `lsp` subcommand for `fmt` (same binary), so a custom
  -- `cmd = { '/custom/path/to/hella', 'lsp' }` keeps working. Set an
  -- explicit command to override, e.g. `cmd = { 'hella', 'fmt' }`.
  format = {
    enabled = true,
    cmd = nil,
    on_save = true,
  },

  -- Auto-close `do`/`has` blocks with `end`: pressing Enter on a blank
  -- new line below a line ending in `do`/`has` inserts the `end` line
  -- (endwise-style, no dependencies)
  endwise = {
    enabled = true,
  },

  -- Diagnostic display options
  diagnostics = {
    enable = true,
    virtual_text = true,
    signs = true,
    underline = true,
    update_in_insert = false,
  },

  -- Notifications (server start/failure, formatting) are off by default
  notify = false,
}

--- Runtime configuration (deep-merged from defaults + user opts)
M.config = vim.deepcopy(M.defaults)

-- Forward declarations (defined below, used by M.setup).
local hook_endwise

--- Setup the plugin
---
--- @param opts? table User overrides for M.defaults
function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})

  if M.config.auto_start then
    vim.api.nvim_create_autocmd('FileType', {
      pattern = 'hella',
      group = vim.api.nvim_create_augroup('hella-lsp', { clear = true }),
      callback = function() M.start() end,
    })
  end

  if M.config.format and M.config.format.on_save then
    vim.api.nvim_create_autocmd('BufWritePre', {
      pattern = { '*.hlt', '*.holt', '*.hll' },
      group = vim.api.nvim_create_augroup('hella-fmt-on-save', { clear = true }),
      callback = function() M.format({ on_save = true }) end,
    })
  end

  if M.config.endwise and M.config.endwise.enabled then
    hook_endwise()
  end
end

--- Find the project root for the current buffer
---
--- @return string
local function root_dir()
  local bufname = vim.api.nvim_buf_get_name(0)
  if bufname == '' then
    return vim.fn.getcwd()
  end

  for _, marker in ipairs(M.config.root_markers) do
    local found = vim.fs.find(marker, {
      path = vim.fn.expand('%:p:h'),
      upward = true,
    })
    if #found > 0 then
      return vim.fn.fnamemodify(found[1], ':h')
    end
  end
  return vim.fn.expand('%:p:h')
end

--- Buffer-local setup when the client attaches: keymaps + diagnostics.
--- Passed via `vim.lsp.start({ on_attach = ... })` so it runs *inside* the
--- real attach flow (didOpen, changetracking, LspAttach).
local function on_attach(client, bufnr)
  local default_opts = { buffer = bufnr, silent = true }
  if type(M.config.keymaps) == 'table' then
    for lhs, rhs in pairs(M.config.keymaps) do
      vim.keymap.set('n', lhs, rhs, default_opts)
    end
  end

  local diag = M.config.diagnostics or {}
  if diag.enable == false then
    vim.diagnostic.enable(false, { bufnr = bufnr })
    return
  end
  local opts = {}
  for _, key in ipairs({ 'virtual_text', 'signs', 'underline', 'update_in_insert' }) do
    if diag[key] ~= nil then
      opts[key] = diag[key]
    end
  end
  if next(opts) ~= nil then
    vim.diagnostic.config(opts, vim.lsp.diagnostic.get_namespace(client.id))
  end
end

--- Start (or restart) the Hella language server for the current buffer
function M.start()
  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].filetype ~= 'hella' then
    return
  end

  -- Bail if a live Hella client is already attached to this buffer.
  -- Stopped clients are detached instead: stop() leaves them attached,
  -- which would both block a fresh start here and crash
  -- textDocument/didSave (no changetracking state was ever registered
  -- for them).
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if client.name == 'hella' then
      if client:is_stopped() then
        pcall(vim.lsp.buf_detach_client, bufnr, client.id)
      else
        return
      end
    end
  end

  local cmd = M.config.cmd
  local dir = root_dir()

  local client_id = vim.lsp.start({
    name = 'hella',
    cmd = cmd,
    root_dir = dir,
    capabilities = M.config.capabilities,
    init_options = {},
    on_attach = on_attach,
  })

  if not client_id then
    if M.config.notify then
      vim.notify('hella.nvim: failed to start language server', vim.log.levels.ERROR)
    end
    return
  end

  if M.config.notify then
    vim.notify(
      string.format('hella.nvim: language server started (%s)', dir),
      vim.log.levels.INFO
    )
  end
end

--- Restart the Hella language server for the current buffer
function M.restart()
  local bufnr = vim.api.nvim_get_current_buf()
  for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
    if client.name == 'hella' then
      -- Detach first: a stopped-but-attached client would make M.start()
      -- bail out and leave the buffer without a live server.
      pcall(vim.lsp.buf_detach_client, bufnr, client.id)
      client:stop()
    end
  end
  M.start()
end

-- Re-entrancy guard for format-on-save: M.format() swaps in the formatted
-- text during BufWritePre, so nested format calls are skipped.
M._formatting = false

--- Resolve the `hella fmt` command list.
---
--- Uses `config.format.cmd` when set; otherwise derives it from the LSP
--- `config.cmd` by replacing the `lsp` subcommand with `fmt` so both go
--- through the same binary.
---
--- @return string[]
local function fmt_cmd()
  local fmt = M.config.format or {}
  if fmt.cmd then
    return fmt.cmd
  end
  local base = {}
  for _, part in ipairs(M.config.cmd or { 'hella', 'lsp' }) do
    if part == 'lsp' then
      base[#base + 1] = 'fmt'
    else
      base[#base + 1] = part
    end
  end
  local has_fmt = false
  for _, part in ipairs(base) do
    if part == 'fmt' then
      has_fmt = true
      break
    end
  end
  if not has_fmt then
    base[#base + 1] = 'fmt'
  end
  return base
end

--- Format the current buffer with `hella fmt` (canonical style, in place).
---
--- The CLI only collects `.hll` files (`collect_sources` skips anything
--- else, and an explicit non-`.hll` file is rejected outright), while this
--- plugin also edits `.hlt`/`.holt` buffers — so the buffer is piped through a
--- temporary `.hll` file and the result is applied back to the buffer.
--- This also means unsaved changes are formatted as-is and unnamed buffers
--- work too; the buffer is marked modified and saving stays up to the user
--- (except under `format.on_save`, where the pending write picks up the
--- formatted text). Mirrors the toolchain behavior (`hella fmt
--- [paths...]` is deterministic and idempotent; `--check` only reports).
---
--- @param opts? table { check?: boolean, on_save?: boolean }
--- @return boolean ok
function M.format(opts)
  opts = opts or {}
  if M._formatting then
    return true
  end
  if M.config.format and M.config.format.enabled == false then
    return false
  end

  local bufnr = vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].filetype ~= 'hella' then
    return false
  end

  M._formatting = true
  local function unlock()
    M._formatting = false
  end
  local function fail(msg)
    unlock()
    if M.config.notify then
      vim.notify('hella.nvim: ' .. msg, vim.log.levels.ERROR)
    end
    return false
  end

  -- Snapshot the buffer (including unsaved changes) into a temp `.hll`
  -- file; the formatter output is read back from the same file.
  -- `fileformat` is untouched: conversion happens only in the temp copy,
  -- the buffer keeps its own line endings until the user saves.
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local tmp = vim.fn.tempname() .. '.hll'
  local ok = pcall(vim.fn.writefile, lines, tmp)
  if not ok then
    return fail('could not stage buffer for formatting')
  end

  local cmd = fmt_cmd()
  local full = {}
  for _, part in ipairs(cmd) do
    full[#full + 1] = part
  end
  if opts.check then
    full[#full + 1] = '--check'
  end
  full[#full + 1] = tmp

  local result
  if vim.system then
    result = vim.system(full, { text = true }):wait()
  else
    local out = vim.fn.system(full)
    result = { code = vim.v.shell_error, stdout = out, stderr = out }
  end

  if result.code ~= 0 then
    local err = (result.stderr and result.stderr ~= '' and result.stderr)
      or (result.stdout and result.stdout ~= '' and result.stdout)
      or string.format('exit code %d', result.code)
    vim.fn.delete(tmp)
    if opts.check and err:match('would be reformatted') then
      -- `--check` exits non-zero for unformatted files by design; that
      -- is a report, not a formatter failure.
      unlock()
      if M.config.notify and not opts.on_save then
        vim.notify('hella.nvim: buffer would be reformatted', vim.log.levels.INFO)
      end
      return false
    end
    return fail('fmt failed: ' .. vim.trim(err))
  end

  if opts.check then
    vim.fn.delete(tmp)
    unlock()
    if M.config.notify and not opts.on_save then
      vim.notify('hella.nvim: already formatted', vim.log.levels.INFO)
    end
    return true
  end

  local formatted = vim.fn.readfile(tmp)
  vim.fn.delete(tmp)
  unlock()

  local current = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local same = #formatted == #current
  if same then
    for i, line in ipairs(formatted) do
      if current[i] ~= line then
        same = false
        break
      end
    end
  end
  if same then
    if M.config.notify and not opts.on_save then
      vim.notify('hella.nvim: already formatted', vim.log.levels.INFO)
    end
    return true
  end

  local view = vim.fn.winsaveview()
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, formatted)
  pcall(vim.fn.winrestview, view)
  if M.config.notify and not opts.on_save then
    local path = vim.api.nvim_buf_get_name(bufnr)
    local label = path ~= '' and vim.fn.fnamemodify(path, ':~:.') or 'buffer'
    vim.notify('hella.nvim: formatted ' .. label, vim.log.levels.INFO)
  end
  return true
end

--- Report whether the current buffer would be reformatted (`hella fmt --check`).
---
--- @return boolean ok
function M.format_check()
  return M.format({ check = true })
end

--- True when `line` (already stripped of trailing whitespace/comments)
--- ends with `word` as a standalone keyword (`do` matches, `mendo`
--- does not).
---
--- @param line string
--- @param word string
--- @return boolean
local function ends_with_keyword(line, word)
  if line == word then
    return true
  end
  if line:sub(-#word) ~= word then
    return false
  end
  return line:sub(-#word - 1, -#word - 1):find('[^%w_]') ~= nil
end

--- Try to auto-close a `do`/`has` block after Enter was pressed.
--- Inspects the post-newline state: the cursor must sit on a blank new
--- line whose previous line ends with a real `do`/`has` keyword, with no
--- `end` already following. Inserts the `end` line and keeps the cursor
--- on the middle line.
---
--- @param bufnr integer
--- @return boolean expanded
local function endwise_apply(bufnr)
  if vim.api.nvim_get_current_buf() ~= bufnr then
    return false
  end
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end
  local row = vim.api.nvim_win_get_cursor(0)[1] -- 1-based, the new line
  if row < 2 then
    return false
  end
  -- Only expand on a blank new line (also guards mid-line splits and
  -- completion/snippet confirmations, which leave text behind).
  local cur = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1]
  if cur == nil or cur:find('%S') then
    return false
  end
  local prev = vim.api.nvim_buf_get_lines(bufnr, row - 2, row - 1, false)[1]
  if prev == nil then
    return false
  end
  local stripped = prev:gsub('%s+$', '')
  stripped = stripped:gsub('%s*//.*$', '')
  local opener = ends_with_keyword(stripped, 'do') and 'do'
    or ends_with_keyword(stripped, 'has') and 'has'
    or nil
  if not opener then
    return false
  end
  -- The keyword must be real code, not string/comment text.
  local col = #stripped - #opener + 1 -- 1-based byte col of the keyword
  local gname = vim.fn.synIDattr(vim.fn.synID(row - 1, col, 1), 'name')
  if
    gname:find('String')
    or gname:find('Comment')
    or gname:find('Character')
    or gname:find('Escape')
  then
    return false
  end
  local base = prev:match('^%s*') or ''
  -- Don't duplicate: scan below for the first line dedented to the
  -- opener's level. If it is an `end`, this block is already closed
  -- (e.g. Enter pressed on a blank body line) — abort. Anything else
  -- (sibling declaration, EOF) means there is nothing closing us.
  for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, row, row + 40, false)) do
    if line:find('%S') then
      local indent = line:match('^%s*') or ''
      if #indent <= #base then
        if line:find('^%s*end%f[%W]') then
          return false
        end
        break
      end
    end
  end
  local sw = vim.fn.shiftwidth()
  local step = vim.bo[bufnr].expandtab and string.rep(' ', sw) or '\t'
  local middle, endl = base .. step, base .. 'end'
  vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, { middle, endl })
  -- The cursor must land past the indent so typing starts cleanly (no
  -- split indent / trailing space). The API clamps to EOL, so briefly
  -- allow one-past-EOL positioning, then restore the option.
  local win = vim.api.nvim_get_current_win()
  local ve = vim.wo[win].virtualedit
  vim.wo[win].virtualedit = 'onemore'
  vim.api.nvim_win_set_cursor(0, { row, #middle })
  vim.wo[win].virtualedit = ve
  return true
end

-- Private test hook: headless Neovim cannot enter insert mode, so
-- keystroke-level tests are impossible; tests drive the same worker the
-- Enter hook calls by constructing the exact post-Enter buffer state.
M._endwise_apply = endwise_apply

--- Install the global Enter watcher for endwise (once). A `vim.on_key`
--- hook is used instead of an insert-mode `<CR>` mapping so completion
--- plugins that own `<CR>` keep working untouched.
function hook_endwise()
  if M._endwise_hooked then
    return
  end
  M._endwise_hooked = true
  local ns = vim.api.nvim_create_namespace('hella-endwise')
  vim.on_key(function(char)
    if char ~= '\r' and char ~= '\n' then
      return
    end
    if not (M.config.endwise and M.config.endwise.enabled) then
      return
    end
    if vim.api.nvim_get_mode().mode ~= 'i' then
      return
    end
    local bufnr = vim.api.nvim_get_current_buf()
    if vim.bo[bufnr].filetype ~= 'hella' then
      return
    end
    vim.schedule(function()
      endwise_apply(bufnr)
    end)
  end, ns)
end

return M
