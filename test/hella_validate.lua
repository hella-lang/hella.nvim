-- Validates the Hella nvim syntax plugin against examples/example.hlt.
-- Run from the plugin root: `nvim -u NONE -S test/hella_validate.lua`.
-- The plugin directory is derived from this script's location, so the
-- checkout may live anywhere.
local src = debug.getinfo(1, 'S').source:sub(2)
local rtp = vim.fn.fnamemodify(src, ':h:h')
vim.cmd('set rtp+=' .. rtp)
vim.cmd('filetype on')
vim.cmd('syntax on')
vim.o.swapfile = false
vim.cmd('edit ' .. rtp .. '/examples/example.hlt')

print('FILETYPE=' .. tostring(vim.bo.filetype))

-- resolved group name at the first byte of word on line line_nr
local function group_at(line_nr, word)
  local line = vim.fn.getline(line_nr) or ''
  local col = line:find(word, 0, true)
  if not col then return '<not-found>' end
  local synid = vim.fn.synID(line_nr, col, 1)
  return vim.fn.synIDattr(synid, 'name')
end

local cases = {
  { 1,   '//',        'hellaLineComment' },
  { 4,   'import',    'hellaStructure' },
  { 7,   '@deprecated', 'hellaAttribute' },
  { 8,   'int',       'hellaType' },
  { 8,   'fib',       'hellaFunctionCall' },
  { 9,   'if',        'hellaConditional' },
  { 10,  'return',    'hellaStatement' },
  { 18,  'for',       'hellaRepeat' },
  { 18,  'in',        'hellaRepeat' },
  { 26,  'const',     'hellaStructure' },
  { 26,  'double',    'hellaType' },
  { 26,  '3.14159',   'hellaFloat' },
  { 27,  '0x7F',      'hellaNumber' },
  { 28,  '0b1010',    'hellaNumber' },
  { 30,  'struct',    'hellaStructure' },
  { 31,  'public',    'hellaStorageClass' },
  { 31,  '0.0',       'hellaFloat' },
  { 42,  'world',     'hellaString' },
  { 44,  'nl',        '' },          -- plain ident: no highlighting
  { 43,  'name',      'hellaInterp' },
  { 44,  '\\n',        'hellaEscape' },
  { 45,  '.5e1',      'hellaFloat' },
  { 46,  '1_000_000', 'hellaNumber' },
  { 53,  'match',     'hellaConditional' },
  { 54,  '->',        'hellaOperator' },
  { 59,  'while',     'hellaRepeat' },
  { 61,  'is',        'hellaOperatorWord' },
  { 62,  'break',     'hellaStatement' },
  { 66,  'defer',     'hellaStatement' },
  { 67,  'assert',    'hellaStatement' },
  { 68,  'debug_assert', 'hellaStatement' },
}

local pass, fail = 0, 0
for _, c in ipairs(cases) do
  local actual = group_at(c[1], c[2])
  local ok = actual == c[3]
  print(string.format('%s L%-3d %-12s -> %s (want %s)',
    ok and 'PASS' or 'FAIL', c[1], c[2], actual, c[3]))
  if ok then pass = pass + 1 else fail = fail + 1 end
end
print('RESULT: ' .. pass .. ' passed, ' .. fail .. ' failed')

vim.cmd('qa!')
