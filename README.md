# hella.nvim

Complete Neovim plugin for the **Hella** programming language.

Provides:
- **Syntax highlighting** — all Hella keywords, operators, literals, strings
  (including raw `r"..."`, multiline `"""..."""`, and interpolation `{ expr }`),
  attributes, comments, and TODO/FIXME highlighting.
- **LSP integration** — connects to the Hella language server (`hella lsp`)
  for diagnostics, hover, goto-definition, completions, and document symbols.
- **Formatting** — runs the canonical formatter (`hella fmt`) on the
  current buffer, with format-on-save enabled by default.
- **Auto-close blocks** — pressing Enter below a line ending in `do` or
  `has` inserts the matching `end` (endwise-style, no dependencies).

> Previously `holt.nvim`: the module is now `hella`, the filetype is
> `hella`, highlight groups are `hella*`, and commands are `:HellaFormat` /
> `:HellaFormatCheck`.

## Requirements

- Neovim 0.10 or newer.
- The `hella` CLI on your PATH (provides the `lsp` and `fmt`
  subcommands this plugin uses).

## Prerequisites

Install the toolchain and its standard library:

```bash
# From a checkout of the Hella toolchain repository
cargo install --path crates/hella-cli
hella setup   # install the standard library to ~/.hella/lib
```

Verify it works:

```bash
hella --help
hella fmt --help
```

## Installation

### lazy.nvim

```lua
{
  "hella-lang/hella.nvim",
  ft = { "hella" },
  config = function()
    require("hella").setup()
  end,
}
```

For LazyVim, put that in a file like `~/.config/nvim/lua/plugins/hella.lua`
(returning the spec table).

### vim-plug

```vim
Plug 'hella-lang/hella.nvim'
```

Then run `:PlugInstall`.

### Manual

Clone the repository somewhere on your runtimepath, e.g.:

```bash
git clone https://github.com/hella-lang/hella.nvim ~/.config/nvim/pack/plugins/start/hella.nvim
```

## Usage

1. Open a `.hll` file (`.hlt` and `.holt` legacy extensions also work).
2. The filetype is detected automatically; syntax highlighting activates.
3. The LSP server starts automatically (if `auto_start` is enabled, which is
   the default).

The default keymaps (buffer-local) are:

| Key             | Action                  |
|-----------------|-------------------------|
| `K`             | Hover                   |
| `<leader>gd`   | Go to definition        |
| `<leader>gr`   | Find references         |
| `<leader>gD`   | Go to type definition   |
| `<leader>gi`   | Go to implementation    |
| `<leader>rn`   | Rename symbol           |
| `<leader>ca`   | Code action             |
| `<leader>f`    | Format buffer (`hella fmt`) |

## Formatting

The plugin formats via the canonical toolchain formatter
(`hella fmt [paths...] [--check]`):
4-space indent, 100-column structural wrapping, expanded blocks, blank-line
normalization, variable/field alignment, and class member categorization.
Formatting is deterministic and idempotent.

This intentionally goes through the CLI, not LSP: the language server does
not advertise `documentFormattingProvider` (editor/LSP integration is still
a planned extension of the formatter), so `vim.lsp.buf.format()` would be
a no-op.

Commands and API:

- `:HellaFormat` — format the current buffer (unsaved changes included; buffer is marked modified, saving stays up to you)
- `:HellaFormatCheck` — report (`hella fmt --check`) without modifying
- `:lua require("hella").format()` / `:lua require("hella").format_check()` — same, programmatically

## Configuration

Call `require("hella").setup({ ... })` to override defaults:

```lua
require("hella").setup({
  -- Custom command to start the Hella language server
  cmd = { "/custom/path/to/hella", "lsp" },

  -- Disable auto-start (you can start manually with :lua require("hella").start())
  auto_start = false,

  -- Disable specific keymaps by setting them to false or removing them
  keymaps = {
    K = function() vim.lsp.buf.hover() end,
    -- remove <leader>f if you don't want formatting
  },

  -- Diagnostic display options
  diagnostics = {
    enable = true,
    virtual_text = true,
    signs = true,
    underline = true,
    update_in_insert = false,
  },

  -- Custom root markers for project detection
  root_markers = { "hella.toml", "Cargo.toml", ".git" },

  -- Canonical formatter (hella fmt). `cmd = nil` (default) derives the
  -- command from `cmd` above by swapping the `lsp` subcommand for `fmt`,
  -- so a custom binary path keeps working. Set explicitly to override.
  format = {
    enabled = true,
    cmd = nil, -- e.g. { "hella", "fmt" }
    on_save = true, -- format-on-save (BufWritePre); set false to disable
  },

  -- Auto-close `do`/`has` blocks with `end` on Enter. Skips strings,
  -- comments, partial words (`mendo`), and blocks that already have an
  -- `end` below the cursor.
  endwise = {
    enabled = true,
  },

  -- Notifications (server start/failure, formatting) are off by default
  notify = false,
})
```

## Highlight groups

All highlight groups are prefixed `hella` and linked to standard Vim groups by
default, so they work with any colorscheme.

Available groups:

| Group                 | Links to   | Highlights                          |
|-----------------------|------------|-------------------------------------|
| `hellaType`           | Type       | `int`, `bool`, `string`, `void`, `arr`, `vec`, `own`, `task`, sized ints (`i8`…`u128`, `uint`), … |
| `hellaConditional`    | Conditional| `if`, `else`, `match`              |
| `hellaRepeat`         | Repeat     | `while`, `loop`, `for`, `in`       |
| `hellaStatement`      | Statement  | `return`, `break`, `assert`, `debug_assert`, `delete`, … |
| `hellaStructure`      | Structure  | `class`, `struct`, `function`, `new`, … |
| `hellaStorageClass`   | StorageClass| `public`, `private`, `static`, …  |
| `hellaOperatorWord`   | Operator   | `and`, `or`, `not`, `is`           |
| `hellaSelf`           | Keyword    | `this`, `super`, `Self`            |
| `hellaKeyword`        | Keyword    | `from`, `to`                       |
| `hellaBoolean`        | Boolean    | `true`, `false`, `null`            |
| `hellaConstant`       | Constant   | `const` declarations               |
| `hellaLineComment`    | Comment    | `// ...` comments                  |
| `hellaBlockComment`   | Comment    | `/* ... */` comments               |
| `hellaCommentTodo`    | Todo       | `TODO`, `FIXME`, `XXX`, `HACK`, `NOTE` |
| `hellaNumber`         | Number     | Integer literals                   |
| `hellaFloat`          | Float      | Float literals                     |
| `hellaString`         | String     | Regular strings                    |
| `hellaRawString`      | String     | Raw strings `r"..."`              |
| `hellaStringDelim`    | String     | String delimiters                  |
| `hellaCharacter`      | Character  | Character literals                 |
| `hellaEscape`         | SpecialChar| Escape sequences                   |
| `hellaBrace`          | SpecialChar| Escaped braces `{{ }}`             |
| `hellaInterp`         | Special    | Interpolation `{ expr }`           |
| `hellaOperator`       | Operator   | Symbols like `+`, `->`, `<<=`, etc.|
| `hellaFunctionCall`   | Function   | Function/method calls              |
| `hellaAttribute`      | Macro      | Attributes `@name(...)`            |

Override any group in your colorscheme or `init.lua`:

```vim
hi hellaType guifg=#61afef gui=italic
hi hellaInterp guifg=#e5c07b
hi hellaAttribute guifg=#c678dd gui=bold
```

## Files

```
hella.nvim/
├── doc/            (optional) :helptags generation
├── lua/hella.lua   Main plugin module (config, LSP handling)
├── plugin/hella.lua Plugin entry point (auto-cmds)
├── syntax/hella.vim Syntax highlighting
├── ftdetect/hella.vim Filetype detection (*.hll, *.hlt, *.holt)
├── ftplugin/hella.vim Filetype settings (comments, suffixes)
├── examples/       Example Hella source files
│   └── example.hlt
└── test/           Validation tests
    └── hella_validate.lua
```

## LSP features

The Hella language server (`hella lsp`) provides:

- **Diagnostics** — compile-time errors from lex → parse → sema pipeline
- **Hover** — symbol type and signature information
- **Go to definition** — jump to function/struct/variable definitions
- **Completion** — keywords and in-scope symbols
- **Document symbols** — outline of the file's symbols

Formatting is **not** an LSP feature: use `:HellaFormat` / `<leader>f`
(`hella fmt` via the CLI) instead.

## Development / Testing

Run the syntax validation test from the plugin root:

```bash
nvim -u NONE -S test/hella_validate.lua
```

This opens `examples/example.hlt` and checks that each highlighted construct
receives the expected syntax group.
