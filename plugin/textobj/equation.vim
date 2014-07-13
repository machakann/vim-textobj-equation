" Vim global plugin to define text-object for function call.
" Last Change: 09-Jul-2014.
" Maintainer : Masaaki Nakamura <mckn@outlook.com>

" License    : NYSL
"              Japanese <http://www.kmonos.net/nysl/>
"              English (Unofficial) <http://www.kmonos.net/nysl/index.en.html>

if exists("g:loaded_textobj_equation")
  finish
endif
let g:loaded_textobj_equation = 1

call textobj#user#plugin('equation', {
      \   '-': {
      \     'select-i-function': 'textobj#equation#equation_i',
      \     'select-i': 'iee',
      \   },
      \ })

call textobj#user#plugin('lhs', {
      \   '-': {
      \     'select-i-function': 'textobj#equation#lhs_i',
      \     'select-i': 'iel',
      \   },
      \ })

call textobj#user#plugin('rhs', {
      \   '-': {
      \     'select-i-function': 'textobj#equation#rhs_i',
      \     'select-i': 'ier',
      \   },
      \ })

