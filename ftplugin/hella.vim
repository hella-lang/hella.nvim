" ============================================================================
" File:        ftplugin/hella.vim
" Description: Filetype-specific settings for Hella source files.
" ============================================================================

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

" Comments are `//` (line) and `/* */` (block) per EBNF §3.
setlocal commentstring=//\ %s
setlocal comments=s1:/*,mb:*,ex:*/,://

" Hella files use .hll; .hlt and .holt are legacy aliases.
setlocal suffixesadd=.hll,.hlt,.holt

" Don't force 'formatoptions' that would reformat code on typing.
setlocal formatoptions-=t formatoptions+=croql

let b:undo_ftplugin = "setlocal commentstring< comments< suffixesadd< formatoptions<"