" A ref source for javadoc
" Version: 0.0.1
" Author : pekepeke <pekepekesamurai@gmail.com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

let s:save_cpo = &cpo
set cpo&vim

" config. {{{1
if !exists('g:ref_javadoc_path')  " {{{2
  let g:ref_javadoc_path = ''
  let g:ref_javadoc_path = expand('~/.bin/apps/jdk-6-doc/ja/')
endif

if !exists('g:ref_javadoc_cmd')  " {{{2
  let g:ref_javadoc_cmd =
        \ executable('elinks') ? 'elinks -dump -no-numbering -no-references %s' :
        \ executable('w3m')    ? 'w3m -dump %s' :
        \ executable('links')  ? 'links -dump %s' :
        \ executable('lynx')   ? 'lynx -dump -nonumbers %s' :
        \ ''
endif


let s:source = {'name': 'javadoc'}  " {{{1

function! s:source.available()  " {{{2
  return isdirectory(g:ref_javadoc_path) &&
        \      len(g:ref_javadoc_cmd)
endfunction
function! s:source.get_body(query)  " {{{2
  let file = s:find_file(a:query)
  if file != ''
    return s:execute(file)
  endif

  let caches = []
  for kind in s:get_javadoc_kinds()
    let caches += s:cache(kind)
  endfor
  if a:query == ''
    return caches
  else
    let kwd = escape(a:query, '.\')
    let op = kwd =~# '[A-Z]' ? '#' : '?'
    call filter(caches, 'v:val =~'.op.' kwd')
    if len(caches) == 1
      let file = s:find_file(caches[0])
      if file != ''
        return s:execute(file)
      endif
    elseif len(caches) > 1
      return caches
    endif
  endif

  throw 'no match: ' . a:query
endfunction



function! s:source.opened(query)  " {{{2
  call s:syntax()
endfunction



function! s:source.complete(query)  " {{{2
  let query = a:query
  let op = query =~# '[A-Z]' ? '#' : '?'

  for kind in s:get_javadoc_kinds()
    let list = filter(copy(s:cache(kind)), 'v:val =~'.op.' query')
    if list != []
      return list
    endif
  endfor
  return []
endfunction



function! s:source.get_keyword()  " {{{2
  let isk = &l:isk
  setlocal isk& isk+=- isk+=. isk+=:
  let kwd = expand('<cword>')
  let &l:isk = isk
  if strpart(kwd, 0, 1) ==# toupper(strpart(kwd, 0, 1)) && exists("b:ref_history_pos")
    let buf_prefix = substitute(b:ref_history[b:ref_history_pos][1], '[A-Z]*$', '', '')
    if buf_prefix != ""
      let kwd = buf_prefix . kwd
    endif
  endif
  return kwd
endfunction



" functions. {{{1

function! s:get_root_directories() "{{{2
  let files = s:get_index_files([
        \ g:ref_javadoc_path . '/api/',
        \ g:ref_javadoc_path . '/jre/api/*/*/',
        \ g:ref_javadoc_path . '/jdk/api/*/*/',
        \ ])
  return map(files,
        \ 'substitute(v:val, "/\\+allclasses-\\(no\\)\\?frame\\.html$", "", "")')
endfunction

function! s:get_index_files(re_paths) " {{{2
  let files = []
  for re_path in a:re_paths
    let files += split(glob(re_path . '/allclasses-noframe\.html'), "\n")
  endfor
  return files
endfunction
function! s:get_javadoc_kinds() "{{{2
  return map(s:get_root_directories(),
        \ 'substitute(v:val, "'.g:ref_javadoc_path.'/", "", "")')
endfunction
function! s:find_file(query) " {{{2
  let kwd = substitute(a:query, '\.', '/', 'g')
  for name in [kwd, substitute(kwd, '/(.*$)', '.\1', '')]
    for pre in s:get_root_directories()
      let file = pre . '/' . name . '.html'
      if filereadable(file)
        return file
      endif

      let file = pre . name . '/package-summary.html'
      if filereadable(file)
        return file
      endif
    endfor
  endfor
  return ''
endfunction
function! s:syntax()  " {{{2
  if exists('b:current_syntax') && b:current_syntax == 'ref-javadoc'
    return
  endif

  syntax clear

  unlet! b:current_syntax
  syntax include @refjavadocJava syntax/java.vim

  syntax match refjavadocJavaLang 'java\.lang\.\w*\|\<\(Object\|String\)\>'
  syntax match refjavadocFunc     '\h\w*\.\?\w*\ze\s*('
  syntax match refjavadocClassdef '\<\(abstract\|class\|extends\|implements\)\>'
  syntax match refjavadocTypedef  '\<\(public\|protected\|private\|static\|final\)\>'
  syntax match refjavadocType     '\<\(void\|int\|long\|double\|float\|boolean\|byte\|char\)\>'

  highlight default link refjavadocJavaLang javaSpecial
  highlight default link refjavadocFunc javaFuncDef
  highlight default link refjavadocClassdef javaClassDecl
  highlight default link refjavadocTypedef javaTypedef
  highlight default link refjavadocType javaType

  let b:current_syntax = 'ref-javadoc'
endfunction



function! s:execute(file)  "{{{2
  if type(g:ref_javadoc_cmd) == type('')
    let cmd = split(g:ref_javadoc_cmd, '\s\+')
  elseif type(g:ref_javadoc_cmd) == type([])
    let cmd = copy(g:ref_javadoc_cmd)
  else
    return ''
  endif

  let file = escape(a:file, '\')
  let res = ref#system(map(cmd, 'substitute(v:val, "%s", file, "g")')).stdout
  if &termencoding != '' && &termencoding !=# &encoding
    let converted = iconv(res, &termencoding, &encoding)
    if converted != ''
      let res = converted
    endif
  endif
  return res
endfunction



function! s:gather_func(name)  "{{{2
  for fname in ['allclasses-noframe.html', 'allclasses-frame.html']
  if filereadable(g:ref_javadoc_path.'/'.a:name.'/'.fname)
    let list = readfile(g:ref_javadoc_path.'/'.a:name.'/'.fname)
    call map(filter(list, 'v:val =~# "<A HREF="'), 'substitute(v:val, ".*A HREF=\"\\(.*\\)\\.html\".*", "\\1", "")')
    return map(list, 'substitute(v:val, "/", ".", "g")')
  endfor
endfunction



function! s:func(name)  "{{{2
  return function(matchstr(expand('<sfile>'), '<SNR>\d\+_\zefunc$') . a:name)
endfunction



function! s:cache(kind)  " {{{2
  return ref#cache('javadoc', a:kind, s:func('gather_func'))
endfunction



function! ref#javadoc#define()  " {{{2
  return s:source
endfunction
call ref#register_detection('java', 'javadoc')



let &cpo = s:save_cpo
unlet s:save_cpo
