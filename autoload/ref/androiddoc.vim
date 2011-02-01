" A ref source for android api doc
" Version: 0.0.1
" Author : pekepeke <pekepekesamurai@gmail.com>
" License: Creative Commons Attribution 2.1 Japan License
"          <http://creativecommons.org/licenses/by/2.1/jp/deed.en>

let s:save_cpo = &cpo
set cpo&vim

" config. {{{1
let s:is_mac = has('macunix') || (executable('uname') && system('uname') =~? '^darwin')
let s:is_win = has('win16') || has('win32') || has('win64')
function! s:find_sdk_path() " {{{2
  if exists('$ANDROID_HOME')
    return $ANDROID_HOME
  elseif s:is_win
    for d in split(glob($PROGRAMFILES.'android-sdk-windows*'), "\n")
      if isdirectory(d) | return d | endif
    endfor
  elseif s:is_mac
    for d in split(glob('/Applications/android-sdk-mac_*'), "\n")
      if isdirectory(d) | return d | endif
    endfor
  endif
  return ''
endfunction
if !exists('g:ref_android_sdk_path')  " {{{2
  let g:ref_android_sdk_path = s:find_sdk_path()
endif

if !exists('g:ref_androiddoc_cmd')  " {{{2
  let g:ref_androiddoc_cmd =
        \ executable('elinks') ? 'elinks -dump -no-numbering -no-references %s' :
        \ executable('w3m')    ? 'w3m -dump %s' :
        \ executable('links')  ? 'links -dump %s' :
        \ executable('lynx')   ? 'lynx -dump -nonumbers %s' :
        \ ''
endif


let s:source = {'name': 'androiddoc'}  " {{{1

function! s:source.available()  " {{{2
  return isdirectory(g:ref_android_sdk_path) &&
        \      len(g:ref_androiddoc_cmd)
endfunction
function! s:source.get_body(query)  " {{{2
  let file = s:find_file(a:query)
  if file != ''
    return s:execute(file)
  endif

  let kind = 'android'
  let caches = copy(s:cache(kind))

  if a:query == ''
    return caches
  else
    let kwd = escape(a:query, '.\')
    call filter(caches, 'v:val =~? kwd')
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
  let line = search('^Summary:', 'bn')
  if line
    execute "normal! ".(line+5)."z\<CR>"
  endif
  call s:syntax()
endfunction



function! s:source.complete(query)  " {{{2
  let name = a:query

  let kind = 'android'
  let list = filter(copy(s:cache(kind)), 'v:val =~# name')
  return list
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
function s:get_document_dir() " {{{2
  if g:ref_android_sdk_path != ''
    return g:ref_android_sdk_path.'/docs/reference'
  endif
  return ''
endfunction
function! s:find_file(query) " {{{2
  let kwd = substitute(a:query, '\.', '/', 'g')
  let pre = s:get_document_dir()
  for name in [kwd, substitute(kwd, '/(.*$)', '.\1', '')]
    let file = pre . '/' . name . '.html'
    if filereadable(file)
      return file
    endif

    let file = pre . name . '/package-summary.html'
    if filereadable(file)
      return file
    endif
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
  let path = s:get_document_dir() . '/classes.html'
  if filereadable(path)
    let list = readfile(path)
    call filter(list, 'v:val =~# "<a href=\"\\.\\./reference/.*/[A-Z].*\\.html\""')
    call map(list, 'substitute(v:val, ".*<a href=\"\\.\\./reference/\\(.*\\).html.*", "\\1", "")')
    return map(list, 'substitute(v:val, "/", ".", "g")')
  endif
  return []
endfunction



function! s:func(name)  "{{{2
  return function(matchstr(expand('<sfile>'), '<SNR>\d\+_\zefunc$') . a:name)
endfunction



function! s:cache(kind)  " {{{2
  return ref#cache('androiddoc', a:kind, s:func('gather_func'))
endfunction



function! ref#androiddoc#define()  " {{{2
  return s:source
endfunction
call ref#register_detection('android', 'androiddoc')



let &cpo = s:save_cpo
unlet s:save_cpo
