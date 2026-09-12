" ============================================================================
" File:        ftdetect/hella.vim
" Description: Detect Hella source files by extension.
"
" `.hll` is the canonical extension (see references/toolchain.md in the
" hella repo); `.hlt` and `.holt` are legacy aliases from the Holt days
" and still work.
" ============================================================================

au BufRead,BufNewFile *.hll,*.hlt,*.holt setfiletype hella