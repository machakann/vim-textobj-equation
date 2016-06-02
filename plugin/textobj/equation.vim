" The vim textobject plugin to selet a equation like text block.
" Last Change: 16-May-2016.
" Maintainer : Masaaki Nakamura <mckn@outlook.jp>

" License    : NYSL
"              Japanese <http://www.kmonos.net/nysl/>
"              English (Unofficial) <http://www.kmonos.net/nysl/index.en.html>

if exists("g:loaded_textobj_equation")
  finish
endif
let g:loaded_textobj_equation = 1

onoremap <silent> <Plug>(textobj-equation-i) :<C-u>call textobj#equation#i('o')<CR>
xnoremap <silent> <Plug>(textobj-equation-i) :<C-u>call textobj#equation#i('x')<CR>
onoremap <silent> <Plug>(textobj-equation-a) :<C-u>call textobj#equation#a('o')<CR>
xnoremap <silent> <Plug>(textobj-equation-a) :<C-u>call textobj#equation#a('x')<CR>

""" default keymappings
" If g:textobj_equation_no_default_key_mappings has been defined, then quit immediately.
if exists('g:textobj_equation_no_default_key_mappings') | finish | endif

omap ie <Plug>(textobj-equation-i)
xmap ie <Plug>(textobj-equation-i)
omap ae <Plug>(textobj-equation-a)
xmap ae <Plug>(textobj-equation-a)
