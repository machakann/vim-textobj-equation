
let s:save_cpo = &cpo
set cpo&vim

let s:V = vital#of('textobj_equation')
let s:L = s:V.import('Data.List')
unlet s:V

function! textobj#equation#equation_i()
  return s:prototype('e')
endfunction

function! textobj#equation#lhs_i()
  return s:prototype('l')
endfunction

function! textobj#equation#rhs_i()
  return s:prototype('r')
endfunction

let s:textobj_equation_patterns = {}
let s:textobj_equation_patterns.cont = ['', '']
let s:textobj_equation_patterns.list = [
      \   ['[+*/-]\?=', '', '', [['(', ')']]],
      \   ['\%(==\|<>\|!=\|[<>]=\?\)', '\%(|\{1,2}\|&\{1,2}\)',  '\%(|\{1,2}\|&\{1,2}\)', [['(', ')']]],
      \ ]

function! s:prototype(kind) "{{{
  let l:count      = v:count1
  let orig_pos     = [line('.'), col('.')]
  let patterns     = s:user_conf('patterns', s:textobj_equation_patterns)

  " search continuation signs for backward
  let current_line = orig_pos[0]
  let head_line    = current_line
  let tail_line    = current_line
  let cont_head    = get(get(patterns, 'cont', []), 0, '')
  let cont_tail    = get(get(patterns, 'cont', []), 1, '')
  if (cont_head != '') || (cont_tail != '')
    while 1
      if ((cont_head != '') && (match(getline(current_line), '^\s*\zs' . cont_head) >= 0))
        \ || ((cont_tail != '') && (match(getline(current_line - 1), cont_tail . '\ze\s*$') >= 0))
        let current_line -= 1
        let head_line     = current_line

        if current_line == 1
          break
        endif
      else
        break
      endif
    endwhile
  endif

  " search continuation signs for forward
  let current_line = orig_pos[0]
  let last_line    = line('$')
  if (cont_head != '') || (cont_tail != '')
    while 1
      if ((cont_tail != '') && (match(getline(current_line), cont_tail . '\ze\s*$') >= 0))
        \ || ((cont_head != '') && (match(getline(current_line + 1), '^\s*\zs' . cont_head) >= 0))
        let current_line += 1
        let tail_line     = current_line

        if current_line == last_line
          break
        endif
      else
        break
      endif
    endwhile
  endif

  let rank = 0
  let operator_pos  = []
  let operator_list = []
  for pattern in patterns.list
    let rank += 1

    " search equation operators for backward
    let flag = 'bce'
    call cursor(orig_pos)
    while 1
      let pos = searchpos(pattern[0], flag, head_line)
      if pos == [0, 0]
        break
      else
        let flag = 'bc'
        let operator_pos   = [searchpos(pattern[0], flag, head_line), pos]
        let operator_list += [operator_pos + [pattern, rank, s:is_exceptional_syntax(operator_pos[0])]]
        call cursor(operator_pos[0])
      endif

      let flag = 'be'
    endwhile

    " search equation operators for forward
    let flag = 'c'
    call cursor(orig_pos)
    while 1
      let pos = searchpos(pattern[0], flag, tail_line)
      if pos == [0, 0]
        break
      else
        let flag = 'ce'
        let operator_pos   = [pos, searchpos(pattern[0], flag, tail_line)]
        let operator_list += [operator_pos + [pattern, rank, s:is_exceptional_syntax(operator_pos[0])]]
        call cursor(operator_pos[0])
      endif

      let flag = ''
    endwhile
  endfor

  " remove included
  " item : [head_pos, tail_pos, pattern, rank]
  for item in copy(operator_list)
    let filter  = '(v:val == item)'
    let filter .= ' || ((v:val[0][0] < item[0][0]) || ((v:val[0][0] == item[0][0]) && (v:val[0][1] < item[0][1])))'
    let filter .= ' || ((v:val[1][0] > item[1][0]) || ((v:val[1][0] == item[1][0]) && (v:val[1][1] > item[1][1])))'
    call filter(operator_list, filter)
  endfor

  " remove duplicates
  let operator_list = s:L.uniq(operator_list)

  " search equations
  " operator  : [head_pos, tail_pos, pattern, rank]
  " candidate : [lhs_head, rhs_tail, rank, operator_head_pos, operator_tail_pos]
  let candidate_list = []
  let sub_candidate_list = []
  for operator in operator_list
    let candidate = s:find_equation(operator, head_line, tail_line, get(patterns, 'cont', []))

    if (candidate != [])
      if ((candidate[0][0] < orig_pos[0]) || ((candidate[0][0] == orig_pos[0]) && (candidate[0][1] <= orig_pos[1])))
        \   && ((candidate[1][0] > orig_pos[0]) || ((candidate[1][0] == orig_pos[0]) && (candidate[1][1] >= orig_pos[1])))

        let candidate_list += [candidate]
      elseif (candidate[3][0] == orig_pos[0] && candidate[3][1] > orig_pos[1])
        let sub_candidate_list += [candidate]
      endif
    endif
  endfor

  if (candidate_list == []) && (sub_candidate_list == [])
    return 0
  elseif candidate_list == []
    let sub_candidate_list = s:sort_sub_candidates(sub_candidate_list, orig_pos, head_line, tail_line)
    let elected = get(sub_candidate_list, l:count - 1, sub_candidate_list[-1])
  else
    let candidate_list = s:sort_candidates(candidate_list, head_line, tail_line)
    let elected = get(candidate_list, l:count - 1, candidate_list[-1])
  endif

  if a:kind == 'l'
    let elected[1] = s:search_edge_ignoring_continuation(elected[4], get(patterns, 'cont', []), 'b', [head_line, 1])
  elseif a:kind == 'r'
    let elected[0] = s:search_edge_ignoring_continuation(elected[5], get(patterns, 'cont', []),  '', [tail_line, len(getline(tail_line))])
  endif

  return ['v', [0] + elected[0] + [0], [0] + elected[1] + [0]]
endfunction
"}}}
function! s:user_conf(name, default)    "{{{
  let user_conf = a:default

  if exists('g:textobj_equation_' . a:name)
    let user_conf = g:textobj_equation_{a:name}
  endif

  if exists('t:textobj_equation_' . a:name)
    let user_conf = t:textobj_equation_{a:name}
  endif

  if exists('w:textobj_equation_' . a:name)
    let user_conf = w:textobj_equation_{a:name}
  endif

  if exists('b:textobj_equation_' . a:name)
    let user_conf = b:textobj_equation_{a:name}
  endif

  return user_conf
endfunction
"}}}
function! s:find_equation(operator, head_line, tail_line, cont)  "{{{
  " search left hand side member
  let candidates  = []
  let candidates += [s:search_edge_from_line_end(a:operator[0], 'b', a:cont, a:head_line)]
  let candidates += [s:search_edge_by_successive_terms(a:operator[0], 'b', a:cont, a:operator[2][3], a:head_line)]
  let candidates += [s:search_edge_by_paired_braket(a:operator[0], 'b', a:operator[2][3], a:cont, a:head_line, a:tail_line)]

  if a:operator[2][1] != ''
    let candidates += [s:search_edge_by_delimiter(a:operator[0], 'b', a:operator[2][1], a:cont, a:head_line)]
  endif

  if a:operator[4]
    let candidates += [s:search_edge_by_syntax(a:operator[0], 'b', a:head_line)]
  endif
  call filter(candidates, 'v:val != [0, 0]')

  if candidates == []
    return []
  elseif len(candidates) == 1
    let lhs_head = candidates[0]
  else
    let lhs_head = s:sort_candidates(map(candidates, '[v:val, a:operator[0], 1, [0, 0], [0, 0]]'), a:head_line, a:tail_line)[0][0]
  endif

  " search right hand side member
  let candidates  = []
  let candidates += [s:search_edge_from_line_end(a:operator[1], '', a:cont, a:tail_line)]
  let candidates += [s:search_edge_by_successive_terms(a:operator[1], '', a:cont, a:operator[2][3], a:tail_line)]
  let candidates += [s:search_edge_by_paired_braket(a:operator[1], '', a:operator[2][3], a:cont, a:head_line, a:tail_line)]

  if a:operator[2][2] != ''
    let candidates += [s:search_edge_by_delimiter(a:operator[1], '', a:operator[2][2], a:cont, a:tail_line)]
  endif

  if a:operator[4]
    let candidates += [s:search_edge_by_syntax(a:operator[1], '', a:tail_line)]
  endif
  call filter(candidates, 'v:val != [0, 0]')

  if candidates == []
    return []
  elseif len(candidates) == 1
    let rhs_tail = candidates[0]
  else
    let rhs_tail = s:sort_candidates(map(candidates, '[a:operator[1], v:val, 1, [0, 0], [0, 0]]'), a:head_line, a:tail_line)[0][1]
  endif

  let rank = a:operator[3]

  return [lhs_head, rhs_tail, rank, a:operator[0], a:operator[1]]
endfunction
"}}}
function! s:search_edge_from_line_end(orig_pos, flag, cont_list, stopline) "{{{
  call cursor([a:stopline, 1])

  if a:flag == 'b'
    let edge = s:search_edge_ignoring_continuation([a:stopline, 1], a:cont_list,  'c', a:orig_pos)
  else
    let edge = s:search_edge_ignoring_continuation([a:stopline, col('$')], a:cont_list, 'bc', a:orig_pos)
  endif

  if synIDattr(synIDtrans(synID(edge[0], edge[1], 1)), "name") == 'Comment'
    if a:flag == 'b'
      let edge = s:search_current_syntax_edge(edge,  '', a:orig_pos[0])
      let edge = s:search_edge_ignoring_continuation(edge, a:cont_list,  '', a:orig_pos)
    else
      let edge = s:search_current_syntax_edge(edge, 'b', a:orig_pos[0])
      let edge = s:search_edge_ignoring_continuation(edge, a:cont_list, 'b', a:orig_pos)
    endif
  endif

  call cursor(a:orig_pos)
  return edge
endfunction
"}}}
function! s:search_edge_by_successive_terms(orig_pos, flag, cont_list, braket, stopline)  "{{{
  call cursor(a:orig_pos)

  let head_cont = (a:cont_list[0] == '') ? '' : (a:cont_list[0] . '\?')
  let tail_cont = (a:cont_list[1] == '') ? '' : (a:cont_list[1] . '\?')

  let bra_pat = '\%(' . join(map(copy(a:braket), 'escape(v:val[0], ''~"\.^$[]*'')'), '\|') . '\)*'
  let ket_pat = '\%(' . join(map(copy(a:braket), 'escape(v:val[1], ''~"\.^$[]*'')'), '\|') . '\)*'

  if a:flag ==# 'b'
    let edge = searchpos('\k\+' . ket_pat . '\s*' . tail_cont . '\_s\+' . head_cont . '\s*\zs' . bra_pat . '\k\+', 'b', a:stopline)
  else
    let edge = searchpos('\k\+' . ket_pat . '\ze\s*' . tail_cont . '\_s\+' . head_cont . '\s*' . bra_pat . '\k\+', 'e', a:stopline)
  endif

  call cursor(a:orig_pos)
  return edge
endfunction
"}}}
function! s:search_edge_by_paired_braket(orig_pos, flag, braket_list, cont_list, head_line, tail_line)  "{{{
  call cursor(a:orig_pos)

  let candidates = []
  let bra_pos    = [0, 0]
  let ket_pos    = [0, 0]
  for braket in a:braket_list
    let bra = braket[0]
    let ket = braket[1]

    if a:flag ==# 'b'
      while 1
        let bra_pos = searchpos(bra, 'be', a:head_line)

        if bra_pos != [0, 0]
          let ket_pos = searchpairpos(bra, '', ket, 'n', 0, a:tail_line)
        else
          break
        endif

        if ket_pos != [0, 0]
          if ((ket_pos[0] > a:orig_pos[0]) || ((ket_pos[0] == a:orig_pos[0]) && (ket_pos[1] > a:orig_pos[1])))
            let candidates += [[s:search_edge_ignoring_continuation(bra_pos, a:cont_list,  '', a:orig_pos), a:orig_pos, 1, [0, 0], [0, 0]]]
          else
            continue
          endif
        else
          break
        endif
      endwhile
    else
      while 1
        let ket_pos = searchpos(ket, '', a:tail_line)

        if ket_pos != [0, 0]
          let bra_pos = searchpairpos(bra, '', ket, 'bn', 0, a:head_line)
        else
          break
        endif

        if bra_pos != [0, 0]
          if ((bra_pos[0] < a:orig_pos[0]) || ((bra_pos[0] == a:orig_pos[0]) && (bra_pos[1] < a:orig_pos[1])))
            let candidates += [[a:orig_pos, s:search_edge_ignoring_continuation(ket_pos, a:cont_list, 'b', a:orig_pos), 1, [0, 0], [0, 0]]]
          else
            continue
          endif
        else
          break
        endif
      endwhile
    endif
  endfor

  if len(candidates) == 0
    let edge = [0, 0]
  elseif len(candidates) == 1
    let edge = (a:flag ==# 'b') ? candidates[0][0] : candidates[0][1]
  else
    let candidates = s:sort_candidates(candidates, a:head_line, a:tail_line)
    let edge = (a:flag ==# 'b') ? candidates[0][0] : candidates[0][1]
  endif

  call cursor(a:orig_pos)
  return edge
endfunction
"}}}
function! s:search_edge_by_delimiter(orig_pos, flag, delimiter, cont_list, stopline)  "{{{
  call cursor(a:orig_pos)
  let delimiter_pos = (a:flag ==# 'b') ? searchpos(a:delimiter, 'be', a:stopline)
        \                              : searchpos(a:delimiter,   '', a:stopline)

  let flag = (a:flag ==# 'b') ? '' : 'b'

  let edge = (delimiter_pos == [0, 0]) ? [0, 0]
        \                              : s:search_edge_ignoring_continuation(delimiter_pos, a:cont_list, flag, a:orig_pos)

  call cursor(a:orig_pos)
  return edge
endfunction
"}}}
function! s:search_edge_by_syntax(orig_pos, flag, stopline) "{{{
  let edge = s:search_current_syntax_edge(a:orig_pos, a:flag, a:stopline)

  if a:flag == 'b'
    normal! l
  else
    normal! h
  endif
  let edge = [line('.'), col('.')]

  return edge
endfunction
"}}}
function! s:search_edge_ignoring_continuation(init_pos, cont_list, flag, stop_pos)  "{{{
  let edge = [-1, -1]
  let head_cont_pat = '^\s*\zs' . a:cont_list[0]
  let tail_cont_pat = a:cont_list[1] . '\ze\s*$'
  let head_cont_pos = [-1, -1]
  let tail_cont_pos = [-1, -1]

  if a:flag ==# 'b'
    let flag1 = 'be'
    let flag2 = 'b'
  elseif a:flag == ''
    let flag1 = ''
    let flag2 = 'e'
  elseif a:flag == 'bc'
    let flag1 = 'bce'
    let flag2 = 'b'
  elseif a:flag == 'c'
    let flag1 = 'c'
    let flag2 = 'e'
  endif

  let current_pos = a:init_pos
  call cursor(current_pos)
  while 1
    if (edge != [0, 0]) && ((edge == head_cont_pos) || (edge == tail_cont_pos))
      " search line-head continuation
      if a:cont_list[0] != ''
        let head_cont_pos = searchpos(head_cont_pat, flag1, a:stop_pos[0])
        call cursor(current_pos)
      endif

      " search line-end continuation
      if a:cont_list[1] != ''
        let tail_cont_pos = searchpos(tail_cont_pat, flag1, a:stop_pos[0])
        call cursor(current_pos)
      endif

      " search the first non-space character
      let edge = searchpos('\S', flag1, a:stop_pos[0])
      call cursor(current_pos)

      if edge == head_cont_pos
        let current_pos = searchpos(head_cont_pat, flag2, a:stop_pos[0])
      elseif edge == tail_cont_pos
        let current_pos = searchpos(tail_cont_pat, flag2, a:stop_pos[0])
      endif
    else
      break
    endif
  endwhile

  if (a:flag == 'b') || (a:flag == 'bc')
    if (edge[0] < a:stop_pos[0]) || ((edge[0] == a:stop_pos[0]) && (edge[1] <= a:stop_pos[1]))
      let edge = [0, 0]
    endif
  elseif (a:flag == '') || (a:flag == 'c')
    if (edge[0] > a:stop_pos[0]) || ((edge[0] == a:stop_pos[0]) && (edge[1] >= a:stop_pos[1]))
      let edge = [0, 0]
    endif
  endif

  call cursor(a:init_pos)
  return edge
endfunction
"}}}
function! s:search_current_syntax_edge(orig_pos, flag, stopline)  "{{{
  call cursor(a:orig_pos)
  let syntax = synIDattr(synIDtrans(synID(a:orig_pos[0], a:orig_pos[1], 1)), "name")

  let current_line = a:orig_pos[0]
  let current_col  = a:orig_pos[1]
  if a:flag == 'b'
    while current_line >= a:stopline
      let list = reverse(map(range(1, current_col), 'synIDattr(synIDtrans(synID(current_line, v:val, 1)), "name") == syntax'))

      let find = 0
      for bool in list
        if bool == 0
          let current_col += 1
          let find = 1
          break
        endif

        let current_col -= 1
      endfor

      if find == 1
        break
      endif

      let current_line -= 1
      call cursor(current_line, 1)
      let current_col = col('$')
    endwhile
  else
    while current_line <= a:stopline
      let list = map(range(current_col, col('$')), 'synIDattr(synIDtrans(synID(current_line, v:val, 1)), "name") == syntax')

      let find = 0
      for bool in list
        if bool == 0
          let find = 1
          let current_col -= 1
          break
        endif

        let current_col += 1
      endfor

      if find == 1
        break
      endif

      let current_line += 1
      call cursor(current_line, 1)
      let current_col = 1
    endwhile
  endif

  call cursor(current_line, current_col)
  return [current_line, current_col]
endfunction
"}}}
function! s:sort_candidates(candidates, top_line, bottom_line)  "{{{
  let length_list = map(getline(a:top_line, a:bottom_line), 'len(v:val) + 1')

  let idx = 0
  let accummed_length = 0
  let accummed_list   = [0]
  for length in length_list[1:]
    let accummed_length  = accummed_length + length_list[idx]
    let accummed_list   += [accummed_length]
    let idx += 1
  endfor

  " candidates == [[[head_pos], [tail_pos], rank, distance], ...]
  let candidates = map(copy(a:candidates), '[v:val[0], v:val[1], v:val[2], ((accummed_list[v:val[1][0] - a:top_line] - v:val[0][1] + 1) + v:val[1][1]), v:val[3], v:val[4]]')

  return sort(candidates, 's:compare_rank')
endfunction
"}}}
function! s:sort_sub_candidates(candidates, orig_pos, top_line, bottom_line)  "{{{
  let length_list = map(getline(a:top_line, a:bottom_line), 'len(v:val) + 1')

  let idx = 0
  let accummed_length = 0
  let accummed_list   = [0]
  for length in length_list[1:]
    let accummed_length  = accummed_length + length_list[idx]
    let accummed_list   += [accummed_length]
    let idx += 1
  endfor

  " candidates == [[[head_pos], [tail_pos], rank, distance], ...]
  let candidates = map(copy(a:candidates), '[v:val[0], v:val[1], v:val[2], ((accummed_list[v:val[3][0] - a:top_line] - a:orig_pos[1] + 1) + v:val[3][1]), v:val[3], v:val[4]]')

  return sort(candidates, 's:compare_rank')
endfunction
"}}}
function! s:compare_rank(i1, i2) "{{{
  if a:i1[3] < a:i2[3]
    return -1
  elseif a:i1[3] > a:i2[3]
    return 1
  else
    return a:i2[2] - a:i1[2]
  endif
endfunction
"}}}
function! s:is_exceptional_syntax(pos)  "{{{
  let syntax = synIDattr(synIDtrans(synID(a:pos[0], a:pos[1], 1)), "name")

  if syntax ==? 'String'
    return 1
  elseif syntax ==? 'Comment'
    return 2
  elseif syntax ==? 'Character'
    return 3
  else
    return 0
  endif
endfunction
"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set foldmethod=marker:
" vim:set commentstring="%s:
