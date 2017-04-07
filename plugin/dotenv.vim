if exists('g:loaded_dotenv')
  finish
endif
let g:loaded_dotenv = 1

" Get the value of a variable from the global Vim environment or current
" buffer's .env.
function! DotenvGet(...) abort
  let env = get(b:, 'dotenv', {})
  if !a:0
    " Use this to get the current .env, as b:dotenv is private.
    return env
  endif
  let key = substitute(a:1, '^\$', '', '')
  return exists('$'.key) ? eval('$'.key) : get(env, key, (a:0 > 1 ? a:2 : ''))
endfunction

" Drop in replacement for expand() that takes the current buffer's .env into
" account.
function! DotenvExpand(str, ...) abort
  let str = a:str
  let pat = '\$\(\w\+\)'
  let end = 0
  while 1
    let pos = match(str, pat, end)
    if pos < 0
      break
    endif
    let var = matchstr(str, pat, end)
    let end = pos + len(var)
    let val = DotenvGet(var)
    let str = strpart(str, 0, pos) . (empty(val) ? var : fnameescape(val)) . strpart(str, end)
  endwhile
  return call('expand', [str] + a:000)
endfunction

" Find the nearest .env file.
function! DotenvFile() abort
  return findfile('.env', isdirectory(expand('%')) ? expand('%').';' : '.;')
endfunction

" Read and parse a .env file.
function! DotenvRead(...) abort
  let env = {}
  for file in a:0 ? a:000 : [DotenvFile()]
    call s:read_env(isdirectory(file) ? file.'/.env' : file, env)
  endfor
  return env
endfunction

" Section: Implementation

function! s:lookup(key, env) abort
  if a:key ==# '\n'
    return "\n"
  elseif a:key =~# '^\\'
    return a:key[1:-1]
  endif
  let var = matchstr(a:key, '^\${\zs.*\ze}$\|^\$\zs\(.*\)$')
  if exists('$'.var)
    return eval('$'.var)
  else
    return get(a:env, var, '')
  endif
endfunction

let s:env_cache = {}
let s:interpolation = '\\\=\${.\{-\}}\|\\\=\$\w\+'

function! s:read_env(file, ...) abort
  let file = fnamemodify(a:file, ':p')
  let ftime = getftime(file)
  if ftime < 0
    return {}
  endif
  let [cachetime, lines] = get(s:env_cache, file, [-2, []])
  if ftime != cachetime
    let lines = []
    for line in readfile(file)
      let matches = matchlist(line, '\v\C^%(export\s+)=([[:alnum:]_.]+)%(\s*\=\s*|:\s{-})(''%(\\''|[^''])*''|"%(\\"|[^"])*"|[^#]+)=%( *#.*)?$')
      if !empty(matches)
        call add(lines, matches[1:2])
      endif
    endfor
    let s:env_cache[file] = [ftime, lines]
  endif
  let env = a:0 ? a:1 : {}
  for [key, value] in lines
    if !has_key(env, key)
      if value =~# '^\s*".*"\s*$'
        let value = substitute(value, '\n', "\n", 'g')
        let value = substitute(value, '\\\ze[^$]', '', 'g')
      endif
      let value = substitute(value, '^\s*\([''"]\)\=\(.\{-\}\)\1\s*$', '\2', '')
      let value = substitute(value, s:interpolation, '\=s:lookup(submatch(0), env)', 'g')
      let env[key] = value
    endif
  endfor
  return env
endfunction

function! s:echo_let(var, val) abort
  echohl VimLet
  echon 'let '
  echohl vimEnvvar
  echon '$'.a:var
  echohl vimOper
  echon ' = '
  echohl vimString
  echon string(a:val)
  echohl None
endfunction

function! s:Load(bang, ...) abort
  if !a:0
    let file = DotenvFile()
    if empty(file)
      echohl Comment
      echo "# No dotenv found"
      echohl None
    elseif a:bang
      return 'edit '.fnameescape(file)
    else
      echohl Comment
      echon (&verbose ? '" ' :  '# ').fnamemodify(file, ':~:.')
      echohl None
      let env = get(b:, 'dotenv', DotenvRead())
      for var in sort(keys(env))
        echon "\n"
        if &verbose
          call s:echo_let(var, env[var])
        else
          echohl PreProc
          echon var
          echohl Operator
          echon '='
          echohl String
          echon escape(env[var], ' $"''')
          echohl None
        endif
      endfor
    endif
    return ''
  endif
  let files = map(copy(a:000), 'expand(v:val)')
  if !a:bang
    for file in files
      if !filereadable(file) && !filereadable(file.'/.env')
        return 'echoerr '.string('No .env found at '.file)
      endif
    endfor
  endif
  let env = call('DotenvRead', files)
  let first = 1
  for var in sort(keys(env))
    if &verbose
      if first
        let first = 0
      else
        echon "\n"
      endif
      call s:echo_let(var, env[var])
    endif
    execute 'let $'.var '= env[var]'
  endfor
  return ''
endfunction

command! -bar -bang -nargs=? -complete=file Dotenv exe s:Load(<bang>0, <f-args>)

if !exists('g:dispatch_compilers')
  let g:dispatch_compilers = {}
endif
let g:dispatch_compilers['dotenv'] = ''
let g:dispatch_compilers['foreman run'] = ''

if !exists('g:projectionist_heuristics')
  let g:projectionist_heuristics = {}
endif
if !has_key(g:projectionist_heuristics, "Procfile") && executable('foreman')
  let g:projectionist_heuristics["Procfile"] = {
        \ "Procfile": {"dispatch": "foreman check"},
        \ "*": {"start": "foreman start"}}
endif

augroup dotenvPlugin
  autocmd BufNewFile,BufReadPost .env.* setfiletype sh

  autocmd BufNewFile,BufReadPre * let b:dotenv = DotenvRead()
  autocmd FileType netrw          let b:dotenv = DotenvRead()
augroup END

" vim:set et sw=2 foldmethod=expr foldexpr=getline(v\:lnum)=~'^\"\ Section\:'?'>1'\:getline(v\:lnum)=~#'^fu'?'a1'\:getline(v\:lnum)=~#'^endf'?'s1'\:'=':
