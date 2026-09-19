" ============================================================================
" File:        syntax/hella.vim
" Language:    Hella (Draft 0.4)
" Maintainer:  hella
" Description: Syntax highlighting for the Hella programming language, based
"              on references/ebnf-0.1.txt in the hella repository.
"
" The grammar is derived from the official EBNF:
"   - Keywords:      EBNF sec.2
"   - Comments:      EBNF sec.3   (// line, /* */ block)
"   - Literals:      EBNF sec.4   (int/hex/bin, float, char, string, raw, triple)
"   - Operators:     EBNF sec.5
"   - Types:         EBNF sec.6
"
" Address-priority note: Vim gives priority to the LAST-defined `syn match`
" item when multiple items match at the same position. This file therefore
" defines the symbolic items (operators) FIRST, then everything that must
" take precedence over them (comments, numbers, strings, attributes,
" function calls) AFTER, so e.g. `//` wins over the `/` operator and `@name`
" wins over the `@` operator. Keywords also take priority over pattern matches,
" so `int fib(` highlights `int` as a type.
"
" All highlight groups are prefixed `hella` and linked to standard Vim groups
" so they pick up any colorscheme. Override any group by defining it before
" this file loads (e.g. in your colorscheme) or with `hi hellaType guifg=...`.
" ============================================================================

if exists("b:current_syntax")
  finish
endif

let s:save_cpo = &cpo
set cpo&vim

" ---------------------------------------------------------------------------
" Keywords (EBNF sec.2, sec.6, sec.38)  -- defined first; keywords outweigh matches
" ---------------------------------------------------------------------------

" Primitive types + `any` (EBNF sec.6)
syn keyword hellaType any bool char double float int string void arr vec own task

" Control flow
syn keyword hellaConditional if else match
syn keyword hellaRepeat while loop for in
syn keyword hellaStatement break continue return defer assert debug_assert delete
      \ async await spawn scope yield

" Declarations & structural delimiters
syn keyword hellaStructure class struct trait enum function typedef distinct
      \ const import extern init operator convert extend has do end get set
      \ initialize new

" Visibility / storage / other modifiers
syn keyword hellaStorageClass public private static sealed override open explicit
      \ ref out implements extends where

" Word operators (EBNF sec.5)
syn keyword hellaOperatorWord and or not is

" Special names (EBNF sec.38)
syn keyword hellaSelf this super Self

" Contextual keywords used in conversion / extern / main
syn keyword hellaKeyword from to

" Literals (EBNF sec.4 / sec.8)
syn keyword hellaBoolean true false null
" ---------------------------------------------------------------------------
" Operators (EBNF sec.5)  -- defined early so they lose to comments/
" numbers/strings/attributes that are declared below (last-defined wins).
" ---------------------------------------------------------------------------

" Multi-character operators first: when two matches start at the same column,
" Vim prefers the longest, so multi-char operators are listed before single-char.
for s:op in ['<<=', '>>=', '..=', '?.', '??', '::', '->', '=>', '<<', '>>',
      \ '<=', '>=', '+=', '-=', '*=', '/=', '%=', '&=', '|=', '^=', '==',
      \ '++', '--', '..']
  execute 'syn match hellaOperator "\V' . s:op . '"'
endfor

" Single-character operators (EBNF sec.5).
for s:op in ['+', '-', '*', '/', '%', '<', '>', '=', '&', '|', '^', '~', '?',
      \ '.', '@', ':', ',']
  execute 'syn match hellaOperator "\V' . s:op . '"'
endfor
unlet s:op

" ---------------------------------------------------------------------------
" Numbers (EBNF sec.4)  -- after operators so `.5e1` beats the `.` operator
" ---------------------------------------------------------------------------

" Hex / binary / decimal integers. The trailing lookahead stops the decimal
" branch from stealing the prefix of a float (`1.5`), exponent (`1e5`) or a
" hex/binary literal (`0x`, `0b`).
syn match hellaNumber display
      \ "\v<((0[xX][0-9a-fA-F_]+)|(0[bB][01_]+)|([0-9][0-9_]*))([.eExXbB])@!"

" Floats: 1.5 /  "1." /\".5" /\"1e5" /\"1.5e-3"
syn match hellaFloat display "\v<[0-9][0-9_]*\.[0-9_]*([eE][+-]?[0-9_]+)?([A-Za-z_])@!"
syn match hellaFloat display "\v[^0-9A-Za-z_.]@<=\.\d[0-9_]*([eE][+-]?[0-9_]+)?>"
syn match hellaFloat display "\v<[0-9][0-9_]*[eE][+-]?[0-9_]+>"
" ---------------------------------------------------------------------------
" Comments (EBNF sec.3)  -- after operators so `//` and `/*` win over `/`
" ---------------------------------------------------------------------------

syn match hellaLineComment "//.*$" contains=hellaCommentTodo
syn region hellaBlockComment start="/\*" end="\*/" fold
      \ contains=hellaCommentTodo

syn keyword hellaCommentTodo TODO FIXME XXX HACK NOTE contained

" ---------------------------------------------------------------------------
" Strings & characters (EBNF sec.4)  -- after operators (no / column clash)
" ---------------------------------------------------------------------------

" Escaped braces {{ }} are literals, not interpolation.
syn match hellaBrace contained "\v\{\{|\}\}"

" Interpolation { expression } inside normal / multiline strings.
syn region hellaInterp contained start="{" end="}" contains=hellaBrace

" Escapes: \n \r \t \b \f \0 \\ \" ' \xHH \uHHHH
syn match hellaEscape contained "\v\\([nrtbf0\\"']|x[0-9a-fA-F]{2}|u[0-9a-fA-F]{4})"

" Multiline string """...""" (may contain escapes + interpolation)
syn region hellaString matchgroup=hellaStringDelim keepend fold
      \ start='"""' end='"""'
      \ contains=hellaEscape,hellaBrace,hellaInterp

" Raw string r"..." (no escapes, no interpolation)
syn region hellaRawString matchgroup=hellaStringDelim start='r"' end='"'

" Normal string "..." (single line, escapes + interpolation)
syn region hellaString matchgroup=hellaStringDelim
      \ start='"' skip='\\\.' end='"'
      \ contains=hellaEscape,hellaBrace,hellaInterp

" Character literal '...'
syn region hellaCharacter matchgroup=hellaStringDelim
      \ start="'" skip='\\\.' end="'"
      \ contains=hellaEscape

" ---------------------------------------------------------------------------
" Identifiers, calls & attributes  --after operators so `@name` wins over `@`
" ---------------------------------------------------------------------------

" Function / method call: identifier immediately followed by `(`.
syn match hellaFunctionCall "\v(\@)@<!<[A-Za-z_][A-Za-z0-9_]*>\s*\ze\("

" Attributes: @name, @name(...)
syn match hellaAttribute "\v\@[A-Za-z_][A-Za-z0-9_]*>"
" ---------------------------------------------------------------------------
" Highlight links (override-able)
" ---------------------------------------------------------------------------

hi def link hellaType            Type
hi def link hellaConditional     Conditional
hi def link hellaRepeat          Repeat
hi def link hellaStatement       Statement
hi def link hellaStructure       Structure
hi def link hellaStorageClass    StorageClass
hi def link hellaOperatorWord    Operator
hi def link hellaSelf            Keyword
hi def link hellaKeyword         Keyword
hi def link hellaBoolean         Boolean
hi def link hellaConstant        Constant
hi def link hellaLineComment     Comment
hi def link hellaBlockComment    Comment
hi def link hellaCommentTodo     Todo
hi def link hellaNumber          Number
hi def link hellaFloat           Float
hi def link hellaString          String
hi def link hellaRawString       String
hi def link hellaStringDelim     String
hi def link hellaCharacter       Character
hi def link hellaEscape          SpecialChar
hi def link hellaBrace           SpecialChar
hi def link hellaInterp          Special
hi def link hellaOperator        Operator
hi def link hellaFunctionCall    Function
hi def link hellaAttribute       Macro

" Keep multiline strings / region sync sane on large files.
syn sync minlines=50 maxlines=500

let b:current_syntax = "hella"

let &cpo = s:save_cpo
unlet s:save_cpo
