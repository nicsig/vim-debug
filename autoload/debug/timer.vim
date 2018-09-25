" call timer_start(9296123, {-> execute('echom "hello"')})
fu! s:fold_section() abort "{{{1
    let new_line = substitute(getline('.'), '^', '# ', '')
    call setline('.', ['#'] + [new_line])
    if line('.') !=# 1
        call append(line('.')-1, '')
    endif
endfu

fu! s:format_info(v) abort "{{{1
    return [
          \ 'id: '.a:v.id,
          \ 'repeat: '.a:v.repeat,
          \ 'remaining: '.s:format_time(a:v.remaining),
          \ 'time: '.s:format_time(a:v.time),
          \ 'paused: '.a:v.paused,
          \ 'callback: '.string(a:v.callback),
          \ ]
endfu

fu! s:format_time(v) abort "{{{1
    return a:v <= 999
    \ ?        a:v.'ms'
    \ :    a:v <= 59999
    \ ?        (a:v/1000).'s '.s:format_time(float2nr(fmod(a:v, 1000)))
    \ :    a:v <= 3600000
    \ ?        (a:v/60000).'m '.s:format_time(float2nr(fmod(a:v, 60000)))
    \ :        (a:v/3600000).'h '.s:format_time(float2nr(fmod(a:v, 3600000)))
endfu

fu! debug#timer#info_open() abort "{{{1
    " Why saving the info in a script-local variable?{{{
    "
    " To pass it to the function which will populate the buffer.
    " The  latter  is not  called  from  here,  but  from an  autocmd  installed
    " elsewhere.
    "}}}
    " Ok but why not re-capturing the info from `debug#timer#populate()`?{{{
    "
    " `populate()` will be called by an autocmd listening to `BufNewFile`.
    " When this event will  be fired, some timers may be  started by our plugins
    " (example: `vim-save`). They're noise; we don't want them.
    "
    " We must save the info now, before any event is fired and interferes.
    "}}}
    let s:infos = timer_info()
    if empty(s:infos)
        echo 'no timer is currently running'
        return
    endif
    let tempfile = tempname().'/timer_info'
    exe 'to '.(&columns/3).'vnew '.tempfile
    let &l:pvw = 1
    wincmd p
endfu

fu! debug#timer#populate() abort "{{{1
    if !exists('s:infos')
        let s:infos = timer_info()
    endif
    let infos = map(s:infos, {i,v -> s:format_info(v)})
    unlet s:infos
    let lines = []
    for info in infos
        let lines += info
    endfor
    call setline(1, lines)
    sil %!column -s: -t
    " `s:put_definition()` calls `append()` which is silent, so why `:silent`?{{{
    "
    " Somehow, `:g` has priority, and it's not silent by default.
    "
    " MWE:
    "
    "     nno  <silent>  cd  :<c-u>call FuncA()<cr>
    "     fu! FuncA() abort
    "         .g/^/call FuncB()
    "     endfu
    "     fu! FuncB() abort
    "         call append('.', ['abc', 'def', 'ghi'])
    "     endfu
    "
    " Press `cd`:
    "
    "     3 more lines
    "}}}
    sil keepj keepp g/^callback\s\+function('.\{-}')$/call s:put_definition()
    keepj keepp g/^id\s\+/call s:fold_section()
endfu

fu! s:put_definition() abort "{{{1
    let line = getline('.')
    if line =~# '^callback\s\+function(''<lambda>\d\+'')$'
        let lambda_id = matchstr(line, '\d\+')
        let definition = split(execute('fu {''<lambda>'.lambda_id.'''}'), '\n')
    else
        let func_name = matchstr(line, '^callback\s\+function(''\zs.\{-}\ze'')$')
        let definition = split(execute('fu '.func_name), '\n')
    endif
    call append('.', ['---'] + map(definition, {i,v -> '    '.v}))
endfu

