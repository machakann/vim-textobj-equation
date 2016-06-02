scriptencoding utf-8
let s:save_cpo = &cpo
set cpo&vim

let b:textobj_equation_rules = [
      \   {'bridge': '\_s*=\_s*', 'left': 'for\s\+', 'right': '', 'priority': -10},
      \   {'bridge': '\_s*\%([!<>]=\?\|[≤≥≠]\)\_s*', 'left': '\%(\%(else\)if\|&&\|||\|[<>]=\?\|=\)\s*', 'right': '\s*\%(&&\|||\|[<>]=\?\|=\)'},
      \   {'bridge': '\_s*[=!]\?==\_s*', 'left': '\%(\%(else\)if\|&&\|||\|[<>]=\?\|=\)\s*', 'right': '\s*\%(&&\|||\|[<>]=\?\|=\)'},
      \   {'bridge': '\_s*\.\%([=!]=\|[<>≤≥≠]\|[<>]=\)\_s*', 'left': '\%(\%(else\)if\|&&\|||\|[<>]=\?\|=\)\s*', 'right': '\s*\%(&&\|||\|[<>]=\?\|=\)'},
      \ ]
let b:textobj_equation_continuation = {'braket': [['(', ')'], ['\[', '\]']]}

if !exists('b:did_ftplugin_textobj_equation')
  let b:did_ftplugin_textobj_equation = 1
  if exists('b:undo_ftplugin')
    let b:undo_ftplugin .= ' | '
  else
    let b:undo_ftplugin = ''
  endif
  let b:undo_ftplugin .= 'unlet! b:did_ftplugin_textobj_equation b:textobj_equation_rules b:textobj_equation_continuation'
endif

let &cpo = s:save_cpo
unlet s:save_cpo
