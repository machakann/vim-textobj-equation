" summary
" # : cursor
"       <-> ie
" rhs = l#s
" <-------> ae
"
" <->       ie
" r#s = lhs
" <-------> ae

" variables "{{{
" null valiables
let s:null_coord  = [0, 0]

" patchs
if v:version > 704 || (v:version == 704 && has('patch237'))
  let s:has_patch_7_4_358 = has('patch-7.4.358')
else
  let s:has_patch_7_4_358 = v:version == 704 && has('patch358')
endif
"}}}

let s:save_cpo = &cpo
set cpo&vim

" Interfaces  "{{{
function! textobj#equation#i(mode) abort
  call s:start('i', a:mode)
endfunction

function! textobj#equation#a(mode) abort
  call s:start('a', a:mode)
endfunction

let g:textobj#equation#timeout = get(g:, 'textobj#equation#timeout', 500)
let g:textobj#equation#expand_range = get(g:, 'textobj#equation#expand_range', 100)

let g:textobj_equation_rules = get(g:, 'textobj_equation_rules', [
      \   {'bridge': '\_s*[^=!<>]=\_s*', 'left': '\%(;\|{\|}\)\_s*', 'right': '\_s*\%(;\|{\|}\)', 'priority': -10},
      \   {'bridge': '\_s*[-+/*]=\_s*', 'left': '\%(;\|{\|}\)\_s*', 'right': '\_s*\%(;\|{\|}\)'},
      \   {'bridge': '\_s*[=!<>]=\_s*', 'left': '\%(\%(else\)\?if\|&&\|||\|;\|=\)\_s*', 'right': '\_s*\%(&&\|||\|;\|?\)'},
      \ ])
"}}}

function! s:start(kind, mode) abort  "{{{
  let l:count = v:count1
  let view = winsaveview()
  let currentline = line('.')
  let rules = get(b:, 'textobj_equation_rules', g:textobj_equation_rules)
  let continuation = get(b:, 'textobj_equation_continuation', {})

  let equations = []
  let options = s:shift_options()
  try
    let [topline, botline] = s:search_explicit_continued_line(continuation)
    let bridges = []
    let bridges += s:search_bridge_for('forward', rules, botline)
    let bridges += s:search_bridge_for('backward', rules, topline)
    if bridges != []
      let equations = s:find_equations(bridges, continuation, topline, botline)
    else
      let [topline, botline] = s:expand_range(currentline)
      let equations = s:search_equations(rules, continuation, topline, botline)
    endif
  catch
    echoerr printf('textobj-equation: Unanticipated error. [%s] %s', v:throwpoint, v:exception)
  finally
    call winrestview(view)
    let elected = s:election(equations, l:count)
    call elected.select(a:kind, a:mode)
    call s:restore_options(options)
  endtry
endfunction
"}}}
function! s:shift_options() abort "{{{
  let options = {}
  let options.virtualedit = &virtualedit
  let options.whichwrap   = &whichwrap
  let options.selection   = &selection
  let [&virtualedit, &whichwrap, &selection] = ['onemore', 'h,l', 'inclusive']
  return options
endfunction
"}}}
function! s:restore_options(options) abort  "{{{
  let &virtualedit = a:options.virtualedit
  let &whichwrap   = a:options.whichwrap
  let &selection   = a:options.selection
endfunction
"}}}
function! s:search_explicit_continued_line(continuation) abort  "{{{
  let currentline = line('.')
  let topline = 0
  let botline = 0
  let preposed  = get(a:continuation, 'preposed',  '')
  let postposed = get(a:continuation, 'postposed', '')
  let termination = get(a:continuation, 'termination',  '')

  if preposed !=# '' || postposed !=# ''
    let firstline = 1
    if currentline > firstline
      for i in range(currentline-1, firstline, -1)
        if !((preposed !=# '' && getline(i+1) =~# preposed)
              \ || (postposed !=# '' && getline(i) =~# postposed))
          break
        endif
        let topline = i
      endfor
    endif

    let lastline = line('$')
    if currentline < lastline
      for i in range(currentline+1, lastline)
        if !((preposed !=# '' && getline(i) =~# preposed)
              \ || (postposed !=# '' && getline(i-1) =~# postposed))
          break
        endif
        let botline = i
      endfor
    endif
  endif

  if topline == 0 && botline == 0 && termination !=# ''
    let topline = max([1, search(termination, 'bcnW')])
    let botline = min([search(termination, 'cenW'), line('$')])
  endif

  return [topline, botline]
endfunction
"}}}
function! s:search_bridge_for(direction, rules, stopline) abort  "{{{
  let cursorpos = getpos('.')
  let stopline = a:stopline != 0 ? a:stopline : cursorpos[1]
  let timeout = g:textobj#equation#timeout
  let flag1 = a:direction ==# 'backward' ? 'b' : ''
  let flag2 = 'cen'
  let bridges = []
  for rule in a:rules
    let head = searchpos(rule.bridge, flag1 . 'c', stopline, timeout)
    while head != s:null_coord
      let tail = searchpos(rule.bridge, flag2)
      let bridges += [[rule, head, tail]]
      let head = searchpos(rule.bridge, flag1, stopline, timeout)
    endwhile
    call setpos('.', cursorpos)
  endfor
  return bridges
endfunction
"}}}
function! s:find_equations(bridges, continuation, topline, botline) abort "{{{
  return filter(map(a:bridges, 's:equation(v:val, a:continuation, a:topline, a:botline)'), 'v:val.valid')
endfunction
"}}}
function! s:search_equations(rules, continuation, topline, botline) abort  "{{{
  let equations = []
  let [head, tail] = s:search_innermost_wrapping(a:continuation, 'b', a:topline, a:botline)
  if head == s:null_coord
    normal! ^
    let [head, tail] = s:search_innermost_wrapping(a:continuation, 'b', a:topline, a:botline)
  endif
  for i in range(20)
    if head != s:null_coord && tail != s:null_coord
      let bridges = s:search_bridge_for('backward', a:rules, head[0])
      if bridges != []
        let equations = s:find_equations(bridges, a:continuation, a:topline, a:botline)
        if equations != []
          break
        endif
      endif
    else
      break
    endif
    let [head, _] = s:search_innermost_wrapping(a:continuation, 'b', head[0], tail[0])
  endfor
  return equations
endfunction
"}}}
function! s:equation(bridge, continuation, topline, botline) abort  "{{{
  let equation = deepcopy(s:equation)
  let [rule, head, tail] = a:bridge
  if head != s:null_coord && tail != s:null_coord
    let equation = deepcopy(s:equation)
    let equation.bridge.pattern = rule.bridge
    let equation.bridge.head = head
    let equation.bridge.tail = tail
    let cursorpos = getpos('.')[1:2]
    call cursor(head)
    let brakets = {'braket': [['(', ')'], ['{', '}'], ['\[', '\]']]}
    let [wraphead, wraptail] = s:search_innermost_wrapping(brakets, 'b', head[0], tail[0])
    call cursor(cursorpos)
    let equation.head = s:get_head(rule, head, wraphead, a:topline)
    let equation.tail = s:get_tail(rule, tail, wraptail, a:botline, a:continuation)
    let equation.len = s:get_buf_length(equation.head, equation.tail)
    let equation.valid = 1
    let equation.priority = get(rule, 'priority', 0)
  endif
  return equation
endfunction
"}}}
function! s:get_head(rule, bridgehead, wraphead, topline) abort  "{{{
  call cursor(a:bridgehead)
  let stopline = a:wraphead[0] != 0 ? a:wraphead[0] : a:bridgehead[0]
  let stopline = max(filter([stopline, a:topline], 'v:val > 0'))
  let pattern = get(a:rule, 'left', '')
  let left_edge = pattern !=# '' ? searchpos(pattern, 'be', stopline)
                               \ : copy(s:null_coord)
  if left_edge != s:null_coord
    let head = s:nextpos(left_edge)
  else
    let head = s:get_line_start(stopline)
  endif
  if a:wraphead != s:null_coord && s:is_equal_or_ahead(a:wraphead, head)
    let head = s:nextpos(a:wraphead)
  endif
  return head
endfunction
"}}}
function! s:get_tail(rule, bridgetail, wraptail, botline, continuation) abort  "{{{
  call cursor(a:bridgetail)
  let pattern = get(a:rule, 'right', '')
  if a:botline != 0
    let right_edge = pattern !=# '' ? searchpos(pattern, '', a:botline) : copy(s:null_coord)
    let tail = right_edge != s:null_coord ? s:prevpos(right_edge) : s:get_line_end(a:botline)
  else
    let [_, stopline] = s:expand_range(a:bridgetail[0])
    for i in range(20)
      let currentline = line('.')
      let right_edge = pattern !=# '' ? searchpos(pattern, '', currentline) : copy(s:null_coord)
      if right_edge != s:null_coord
        let tail = s:prevpos(right_edge)
        break
      else
        let last_tail = s:get_line_end(currentline)
        call cursor(last_tail)
        let [head, tail] = s:search_innermost_wrapping(a:continuation, '', currentline, stopline)
        if head == s:null_coord || tail == s:null_coord
              \ || !(head[0] == currentline && s:is_ahead(head, a:bridgetail))
          let tail = last_tail
          break
        endif
      endif
    endfor
  endif
  if a:wraptail != s:null_coord && s:is_equal_or_ahead(tail, a:wraptail)
    let tail = s:prevpos(a:wraptail)
  endif
  return tail
endfunction
"}}}
function! s:get_buf_length(start, end) abort  "{{{
  if a:start[0] == a:end[0]
    let len = a:end[1] - a:start[1] + 1
  else
    let len = (line2byte(a:end[0]) + a:end[1]) - (line2byte(a:start[0]) + a:start[1]) + 1
  endif
  return len
endfunction
"}}}
function! s:search_innermost_wrapping(continuation, flag, topline, botline) abort "{{{
  let timeout = g:textobj#equation#timeout
  let skip = 's:is_string_literal(getpos(''.'')[1:2])'
  let initpos = getpos('.')
  let brakets = get(a:continuation, 'braket', [])
  if brakets == []
    let edges = [copy(s:null_coord), copy(s:null_coord)]
  else
    if stridx(a:flag, 'b') > -1
      let frag1 = 'b'
      let frag2 = 'n'
    else
      let frag1 = 'bcn'
      let frag2 = ''
    endif

    let list = []
    for braket in brakets
      let list += [[
            \   searchpairpos(braket[0], '', braket[1], frag1, skip, a:topline, timeout),
            \   searchpairpos(braket[0], '', braket[1], frag2, skip, a:botline, timeout)
            \ ]]
      call setpos('.', initpos)
    endfor
    call filter(list, 'v:val[0] != s:null_coord && v:val[1] != s:null_coord')
    call s:sort(list, 's:compare_range_inner', 1)
    let edges = get(list, 0, [copy(s:null_coord), copy(s:null_coord)])
  endif

  if edges[0] != s:null_coord && edges[1] != s:null_coord
    let pos = stridx(a:flag, 'b') > -1 ? edges[0] : edges[1]
    call cursor(pos)
  endif
  return edges
endfunction
"}}}
function! s:expand_range(lnum) abort  "{{{
  let expand_range = g:textobj#equation#expand_range
  return [max([1, a:lnum - expand_range]), min([a:lnum + expand_range, line('$')])]
endfunction
"}}}
function! s:compare_range_inner(r1, r2) abort "{{{
  return s:compare_pos(a:r1[0], a:r2[0])
endfunction
"}}}
function! s:compare_range_outer(r1, r2) abort "{{{
  return -s:compare_pos(a:r1[0], a:r2[0])
endfunction
"}}}
function! s:compare_pos(p1, p2) abort "{{{
  return a:p1[0] != a:p2[0] ? a:p2[0] - a:p1[0] : a:p2[1] - a:p1[1]
endfunction
"}}}
function! s:election(equations, count) abort  "{{{
  let cursorpos = getpos('.')[1:2]
  call filter(a:equations, 's:is_in_between(cursorpos, v:val.head, v:val.tail)')
  if len(a:equations) < a:count
    return deepcopy(s:equation)
  endif

  call s:sort(a:equations, 's:compare_len', a:count)
  return a:equations[a:count - 1]
endfunction
"}}}
" function! s:sort(list, func, ...) abort  "{{{
if s:has_patch_7_4_358
  function! s:sort(list, func, ...) abort
    return sort(a:list, a:func)
  endfunction
else
  function! s:sort(list, func, ...) abort
    " NOTE: len(a:list) is always larger than n or same.
    " FIXME: The number of item in a:list would not be large, but if there was
    "        any efficient argorithm, I would rewrite here.
    let len = len(a:list)
    let n = min([get(a:000, 0, len), len])
    for i in range(n)
      if len - 2 >= i
        let min = len - 1
        for j in range(len - 2, i, -1)
          if call(a:func, [a:list[min], a:list[j]]) >= 1
            let min = j
          endif
        endfor

        if min > i
          call insert(a:list, remove(a:list, min), i)
        endif
      endif
    endfor
    return a:list
  endfunction
endif
"}}}
function! s:compare_len(e1, e2) abort "{{{
  return a:e1.priority != a:e2.priority ? a:e2.priority - a:e1.priority : a:e1.len - a:e2.len
endfunction
"}}}
function! s:is_equal_or_ahead(c1, c2) abort  "{{{
  return (a:c1[0] > a:c2[0]) || (a:c1[0] == a:c2[0] && a:c1[1] >= a:c2[1])
endfunction
"}}}
function! s:is_ahead(c1, c2) abort  "{{{
  return (a:c1[0] > a:c2[0]) || (a:c1[0] == a:c2[0] && a:c1[1] > a:c2[1])
endfunction
"}}}
function! s:is_in_between(coord, head, tail) abort  "{{{
  return (a:coord != s:null_coord) && (a:head != s:null_coord) && (a:tail != s:null_coord)
    \  && ((a:coord[0] > a:head[0]) || ((a:coord[0] == a:head[0]) && (a:coord[1] >= a:head[1])))
    \  && ((a:coord[0] < a:tail[0]) || ((a:coord[0] == a:tail[0]) && (a:coord[1] <= a:tail[1])))
endfunction
"}}}
function! s:get_line_start(lnum) abort "{{{
  let initpos = getpos('.')
  call cursor([a:lnum, 1])
  normal! ^
  let line_start = getpos('.')[1:2]
  call setpos('.', initpos)
  return line_start
endfunction
"}}}
function! s:get_line_end(lnum) abort "{{{
  let initpos = getpos('.')
  call cursor([a:lnum, col([a:lnum, '$']) - 1])
  call search('\S', 'bc', a:lnum)
  let line_end = getpos('.')[1:2]
  call setpos('.', initpos)
  return line_end
endfunction
"}}}
function! s:prevpos(coord) abort "{{{
  call cursor(a:coord)
  normal! h
  return getpos('.')[1:2]
endfunction
"}}}
function! s:nextpos(coord) abort "{{{
  call cursor(a:coord)
  normal! l
  return getpos('.')[1:2]
endfunction
"}}}
function! s:is_string_literal(pos) abort  "{{{
  return match(map(synstack(a:pos[0], a:pos[1]), 'synIDattr(synIDtrans(v:val), "name")'), 'String') > -1
endfunction
"}}}

" equation object "{{{
let s:equation = {
      \   'valid': 0,
      \   'head': copy(s:null_coord),
      \   'tail': copy(s:null_coord),
      \   'priority': 0,
      \   'len': 0,
      \   'bridge': {
      \     'pattern': '',
      \     'head': copy(s:null_coord),
      \     'tail': copy(s:null_coord),
      \   },
      \ }
function! s:equation.select(kind, mode) dict abort  "{{{
  let [head, tail] = self._get_region(a:kind)
  if head != s:null_coord && tail != s:null_coord
    normal! v
    call cursor(head)
    normal! o
    call cursor(tail)
  else
    if a:mode ==# 'x'
      normal! gv
    endif
  endif
endfunction
"}}}
function! s:equation._get_region(kind) dict abort "{{{
  if a:kind ==# 'a'
    let head = self.head
    let tail = self.tail
  elseif a:kind ==# 'i'
    let cursor = getpos('.')[1:2]
    if s:is_equal_or_ahead(cursor, self.bridge.head)
      " rhs
      let head = s:nextpos(self.bridge.tail)
      let tail = self.tail
    else
      " lhs
      let head = self.head
      let tail = s:prevpos(self.bridge.head)
    endif
  else
    let null = copy(s:null_coord)
    let head = null
    let tail = null
  endif
  return [head, tail]
endfunction
"}}}
"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set foldmethod=marker:
" vim:set commentstring="%s:
