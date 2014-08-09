if exists('b:did_ftplugin_textobj_equation')
  finish
endif
let b:did_ftplugin_textobj_equation = 1

unlet! b:textobj_equation_patterns
let b:textobj_equation_patterns = {}
let b:textobj_equation_patterns.cont = ['&', '&']
let b:textobj_equation_patterns.list = [
      \   ['[+*/-]\?=', '::', '', [['(', ')']]],
      \   ['\%(==\|/=\|[<>]=\?\|\.lt\.\|\.le\.\|\.eq\.\|\.ne\.\|\.gt\.\|\.ge\.\)', '\%(\.not\.\|\.and\.\|\.or\.\|\.eqv\.\|\.neqv\.\)', '\%(\.not\.\|\.and\.\|\.or\.\|\.eqv\.\|\.neqv\.\)', [['(', ')']]],
      \ ]
