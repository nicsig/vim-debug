" fu! debug#runtime_command(bang, ...) abort
"     let unlets = []
"     let do = []
"     let predo = ''
"
"     if a:0
"         let files = a:000
"     elseif &filetype ==# 'vim' || expand('%:e') ==# 'vim'
"         let files = [debug#locate(expand('%:p'))[1]]
"         if empty(files[0])
"             let files = ['%']
"         endif
"         if &modified && (&autowrite || &autowriteall)
"             let predo = 'sil wall|'
"         endif
"     else
"         for ft in split(&filetype, '\.')
"             for pat in ['ftplugin/%s.vim', 'ftplugin/%s_*.vim', 'ftplugin/%s/*.vim', 'indent/%s.vim', 'syntax/%s.vim', 'syntax/%s/*.vim']
"               call extend(unlets, globpath(&rtp, printf(pat, ft), 0, 1))
"             endfor
"         endfor
"         let run = s:unlet_for(unlets)
"         if run !=# ''
"             let run .= '|'
"         endif
"         let run .= 'filetype detect'
"         echo ':'.run
"         return run
"     endif
"
"     for request in files
"         if request =~# '^\.\=[\\/]\|^\w:[\\/]\|^[%#~]\|^\d\+$'
"             let request = debug#scriptname(request)
"             let unlets += glob(request, 0, 1)
"                                                                  ┌ why double quotes?
"                                                                  │ do we need `\t` to be translated into a tab,
"                                                                  │ or do we need `\` and `t`?
"                                                                  │
"             let do += map(copy(unlets), { i,v -> 'so '.escape(v, " \t|!"))
"         else
"             if get(do, 0, [''])[0] !~# '^runtime!'
"                 let do += ['runtime!']
"             endif
"                                                   ┌ here, tpope uses 1, why?
"                                                   │
"             let unlets += globpath(&rtp, request, 1, 1)
"             let do[-1] .=
"             ' '.escape(request, " \t|!")
"         endif
"     endfor
"     if !a:bang
"         call extend(do, ['filetype detect'])
"     endif
"     let run = s:unlet_for(unlets)
"     if run !=# ''
"         let run .= '|'
"     endif
"     let run .= join(do, '|')
"     echo ':'.run
"     return predo.run
" endfu

" fu! s:unlet_for(files) abort
"     let guards = []
"     for file in a:files
"         if filereadable(file)
"             let lines = readfile(file, '', 500)
"             if len(lines)
"                 for i in range(len(lines)-1)
"                     let unlet = matchstr(lines[i],
"                     \                    '^if .*\<exists *( *[''"]\%(\g:\)\=\zs[0-9A-Za-z_#]\+\ze[''"]')
"                     if unlet !=# '' && index(guards, unlet) == -1
"                         for j in range(0, 4)
"                             if get(lines, i+j, '') =~# '^\s*finish\>'
"                                 call extend(guards, [unlet])
"                                 break
"                             endif
"                         endfor
"                     endif
"                 endfor
"             endif
"         endif
"     endfor
"     if empty(guards)
"         return ''
"     else
"       return 'unlet! '.join(map(guards, { i,v -> 'g:'.v }), ' ')
"     endif
" endfu

" fu! debug#locate(path) abort
"     let path = fnamemodify(a:path, ':p')
"     let candidates = []
"     for glob in split(&runtimepath, ',')
"       let candidates += filter(glob(glob, 0, 1), { i,v -> path[0 : len(v)-1] ==# v && path[len(v)] =~# '[\/]' })
"     endfor
"     if empty(candidates)
"         return ['', '']
"     endif
"     let preferred = sort(candidates, s:function('s:lencompare'))[-1]
"     return [preferred, path[strlen(preferred)+1 : -1]]
" endfu

" fu! s:function(name) abort
"     return function(substitute(a:name,'^s:',matchstr(expand('<sfile>'), '.*\zs<SNR>\d\+_'),''))
" endfu

" fu! s:lencompare(a, b) abort
"     return len(a:a) - len(a:b)
" endfu

" fu! debug#scriptnames_qflist() abort
"     let names = execute('scriptnames')
"     let list = []
"     for line in split(names, '\n')
"         if line =~# ':'
"             call add(list, {'text': matchstr(line, '\d\+'), 'filename': expand(matchstr(line, ': \zs.*'))})
"         endif
"     endfor
"     return list
" endfu

" fu! debug#scriptname(file) abort
"     if a:file =~# '^\d\+$'
"         return get(debug#scriptnames_qflist(), a:file-1, {'filename': a:file}).filename
"     else
"         return a:file
"     endif
" endfu

if exists('g:autoloaded_debug')
    finish
endif
let g:autoloaded_debug = 1

" break {{{1

fu! s:break(type, arg) abort
    if a:arg ==# 'here' || a:arg ==# ''
        " Search for `fu!` backward.
        " Why use `searchpair()` instead of `search()`?{{{
        "
        " There could be  a whole function defined before us  inside the current
        " function.
        "
        " So we need to use `searchpair()`.
        " What `searchpair('fu!', … , 'b')` does, is:
        "
        "       1. initialize a counter to 0
        "       2. look at `fu!` backwards
        "       3. every time `endfu` is found, increase the counter
        "       4. every time `fu!` is found, decrease the counter
        "       5. go on until `fu!` is found, AND the counter is zero
"}}}
        let l:lnum = searchpair('^\s*fu\%[nction]\>.*(', '', '^\s*endf\%[unction]\>', 'Wbn')
        " check you found sth, and it's valid (i.e. before where we are)
        if l:lnum && l:lnum < line('.')
            let function = matchstr(getline(l:lnum), '^\s*\w\+!\?\s*\zs[^( ]*')
            if function =~# '^s:\|^<SID>'
                let id = s:script_id('%')
                if id
                    let function = s:sub(function, '^s:|^\<SID\>', '<SNR>'.id.'_')
                else
                    return 'echoerr "Could not determine script id"'
                endif
            endif
            if function =~# '\.'
                return 'echoerr "Dictionary functions not supported"'
            endif
            return printf('break%s func %d %s',
            \                  a:type,
            \                  line('.') == l:lnum ? '' : line('.') - l:lnum,
            \                  function )
        else
            return 'break'.a:type.' here'
        endif
    endif
    return 'break'.a:type.' '.s:break_snr(a:arg)
endfu

" break_setup {{{1

fu! debug#break_setup() abort
    com! -buffer -bar -nargs=? -complete=customlist,s:complete_breakadd BreakAdd
    \                                                                   exe s:break('add', <q-args>)
    com! -buffer -bar -nargs=? -complete=customlist,s:complete_breakdel BreakDel
    \                                                                   exe s:break('del', <q-args>)

    cnorea <expr> <buffer> breakadd  getcmdtype() ==# ':' && getcmdline() ==# 'breakadd'
    \                                ?    'BreakAdd'
    \                                :    'breakadd'

    cnorea <expr> <buffer> breakdel  getcmdtype() ==# ':' && getcmdline() ==# 'breakdel'
    \                                ?    'BreakDel'
    \                                :    'breakdel'

    let b:undo_ftplugin =         get(b:, 'undo_ftplugin', '')
    \                     .(empty(get(b:, 'undo_ftplugin', '')) ? '' : '|')
    \                     ."
    \                          exe 'cuna   <buffer> breakadd'
    \                        | exe 'cuna   <buffer> breakdel'
    \                        | delc BreakAdd
    \                        | delc BreakDel
    \                      "
endfu

" break_snr {{{1

fu! s:break_snr(arg) abort
    let id = s:script_id('%')
    return id
    \?         s:gsub(a:arg, '^func.*\zs%(<s:|\<SID\>)', '<SNR>'.id.'_')
    \:         a:arg
endfu

" complete_breakadd {{{1

fu! s:capture(excmd) abort
    redir => out
    exe 'sil! '.a:excmd
    redir END
    " return execute(a:excmd, 'silent!')
    return out
endfu

fu! s:complete_breakadd(arglead, cmdline, _p) abort
    " let functions = sort(map(split(execute('function'), '\n'),
    " \                              { i,v -> matchstr(v, ' \zs[^(]*') }
    " \                       )
    " \                   )
    let functions = sort(map(split(s:capture('function'), '\n'),
    \                              { i,v -> matchstr(v, ' \zs[^(]*') }
    \                       )
    \                   )

    let g:debug = a:cmdline =~# '^\w\+\s\+\w*$'
    \?         [ 'here', 'file', 'func' ]
    \:     a:cmdline =~# '^\w\+\s\+func\s*\d*\s\+s:'
    \?         map(functions, { i,v -> s:gsub(v, '\<SNR\>'.s:script_id('%').'_', 's:') })
    \:     a:cmdline =~# '^\w\+\s\+func '
    \?         functions
    \:     a:cmdline =~# '^\w\+\s\+file '
    \?         glob(a:arglead.'*', 0, 1)
    \:         []
    return []
endfu

" complete_breakdel {{{1

fu! s:complete_breakdel(_a, cmdline, _p) abort
    let args = matchstr(a:cmdline, '\s\zs\S.*')
    let list = split(execute('breaklist'), '\n')
    call map(list, { i,v -> s:sub(v,
   \                              '^\s*\d+\s*(\w+) (.*)  line (\d+)$',
   \                              '\1 \3 \2'
   \                             )
   \               })

    return a:cmdline =~# '^\w\+\s\+\w*$'
    \?         [ '*', 'here', 'file', 'func' ]
    \:     a:cmdline =~# '\v^\w+\s+func\s'
    \?         map(filter(list, { i,v -> v =~# '^func' }),
    \              { i,v -> v[5:-1] })
    \:     a:cmdline =~# '\v^\w+\s+file\s'
    \?         map(filter(list, { i,v -> v =~# '^file' }),
    \              { i,v -> v[5:-1] })
    \:         ''
endfu

fu! debug#complete_runtime(arglead, _c, _p) abort "{{{1
    let cheats = {
    \              'a' : 'autoload',
    \              'd' : 'doc',
    \              'f' : 'ftplugin',
    \              'i' : 'indent',
    \              'p' : 'plugin',
    \              's' : 'syntax',
    \            }

    " Purpose:
    " If the lead of the argument begins with `a/` replace it with `autoload/`.
    " Same thing for other kind of idiomatic directories.
    "
    "                                ┌ the lead of the argument begins with a word character
    "                                │ followed by a slash
    "                                │                               ┌ and this character is in `cheats`
    "             ┌──────────────────┤    ┌──────────────────────────┤
    let request = a:arglead =~# '^\w/' && has_key(cheats,a:arglead[0])
    \?                cheats[a:arglead[0]].a:arglead[1:-1]
    \:                a:arglead

    " put a wildcard before every slash, and one at the end
    let pat = substitute(request,'/','*/','g').'*'
    let found = {}
    for path in split(&rtp, ',')
        let matches = glob(path.'/'.pat, 0, 1)
        " append a slash for every match which is a directory
        call map(matches, { i,v -> isdirectory(v) ? v.'/' : v })
        " remove the path (the one in the rtp) from the match
        call map(matches, { i,v -> fnamemodify(v, ':p')[strlen(path)+1:-1] })
        "                                               └────────────┤
        "             `strlen(path) - 1`                             ┘
        "              would include the last character in the path
        "
        "             `strlen(path)`
        "              would include the slash after the path

        for a_match in matches
            let found[a_match] = 1
        endfor
    endfor
    return sort(keys(found))
endfu

" gsub {{{1

fu! s:gsub(str,pat,rep) abort
    return substitute(a:str, '\v\C'.a:pat, a:rep, 'g')
endfu

" messages {{{1

fu! debug#messages() abort
    0Verbose messages

    " From a help buffer, the buffer displayed in a newly opened preview
    " window inherits some settings, such as 'nomodifiable' and 'readonly'.
    " Make sure they're disabled so that we can remove noise.
    setl ma noro

    let noises = {
    \              '[fewer|more] lines': '\d+ %(fewer|more) lines%(; %(before|after) #\d+.*)?',
    \              '1 more line less':   '1 %(more )?line%( less)?%(; %(before|after) #\d+.*)?',
    \              'change':             'Already at %(new|old)est change',
    \              'changes':            '\d+ changes?; %(before|after) #\d+.*' ,
    \              'E21':                "E21: Cannot make changes, 'modifiable' is off",
    \              'E387':               'E387: Match is on current line',
    \              'E486':               'E486: Pattern not found: \S*',
    \              'E492':               'E492: Not an editor command: \S+',
    \              'E501':               'E501: At end-of-file',
    \              'E553':               'E553: No more items',
    \              'E663':               'E663: At end of changelist',
    \              'E664':               'E664: changelist is empty',
    \              'Ex mode':            'Entering Ex mode.  Type "visual" to go to Normal mode.',
    \              'empty lines':        '\s*' ,
    \              'lines filtered':     '\d+ lines filtered' ,
    \              'lines indented':     '\d+ lines [><]ed \d+ times?',
    \              'file loaded':        '".{-}"%( \[RO\])? line \d+ of \d+ --\d+\%-- col \d+%(-\d+)?',
    \              'file reloaded':      '".{-}".*\d+L, \d+C',
    \              'g C-g':              'col \d+ of \d+; line \d+ of \d+; word \d+ of \d+; char \d+ of \d+; byte \d+ of \d+',
    \              'maintainer':         '\mMessages maintainer: Bram Moolenaar <Bram@vim.org>',
    \              'Scanning':           'Scanning:.*',
    \              'substitutions':      '\d+ substitutions? on \d+ lines?',
    \              'verbose':            ':0Verbose messages',
    \              'W10':                'W10: Warning: Changing a readonly file',
    \              'yanked lines':       '%(block of )?\d+ lines yanked',
    \            }

    for noise in values(noises)
        sil! exe 'g/\v^'.noise.'$/d_'
    endfor

    call matchadd('ErrorMsg', '\v^E\d+:\s+.*')
    call matchadd('ErrorMsg', '\v^Vim.{-}:E\d+:\s+.*')
    call matchadd('ErrorMsg', '^Error detected while processing.*')
    call matchadd('LineNr', '\v^line\s+\d+:$')
endfu

fu! debug#messages_old() abort
    " `qfl` is a list of dictionaries
    " each one has the key:
    "
    "         text
    "
    " … and may have 2 other keys:
    "
    "         filename
    "         lnum
    let qfl = []

    " iterate over the messages in the log
    for msg in split(execute('messages'), '\n\+')
        " try to capture the address in a line such as:
        "         line    42:
        let l:lnum = matchstr(msg, '\v\C^line\s+\zs\d+\ze:$')

        "  ┌─ if you found one
        "  │                                             ┌─ and the previous message was an error
        "  │                                             │
        if !empty(l:lnum) && !empty(qfl) && qfl[-1].text =~# '^Error detected while processing'
            " append the line number to the previous message in the qfl
            let qfl[-1].text = substitute(qfl[-1].text, ':$', '['.l:lnum.']:', '')
        else
            call add(qfl, { 'text': msg })
        endif

        " try to capture the chain of function calls:
        "         FuncA[1]..FuncB:
        let chain = matchstr(qfl[-1].text, '\v\s+\zs\S+\]\ze:$')
        if empty(chain)
            continue
        endif

        " remove the chain from the message
        "         Error detected while processing function
        let qfl[-1].text = substitute(qfl[-1].text, '\v\s+\S+:$', '', '')
        " iterate over the function calls in the chain
        "         FuncA[12]
        "         FuncB[34]
        for call in split(chain, '\.\.')
            " add each call to the qfl
            call add(qfl, { 'text': call })

            " get the address where the function was called
            let l:lnum = matchstr(call, '\v\[\zs\d+\ze\]$')
            " get the function name
            let function = substitute(call, '\v\[\d+\]$', '', '')

            " if the name of a function contains a slash, or a dot, it's
            " not a function, it's a file
            "
            " it happens when the error occurred in a sourced file, like
            " a ftplugin; put a garbage command in one of them to reproduce
            if function =~# '[/.]' && filereadable(function)
                let qfl[-1].filename = function
                let qfl[-1].lnum = l:lnum
                let qfl[-1].text = ''
                " there's no chain of calls, the only error comes from this file
                continue
            " if the name of a function is just a number, it's a numbered
            " function, whose real name contains curly braces
            elseif function =~# '^\d\+$'
                let function = '{'.function.'}'
            endif

            " get the name of the file in which the function was defined
            "         Last set from ~/.vim/vimrc
            let definition = split(execute('verb function '.function), '\n')
            let filename = expand(matchstr(get(definition, 1, ''), 'from \zs.*'))

            if !filereadable(filename)
                continue
            endif

            " capture the code inside the function
            let code = definition[2:-2]
            let leading_address = len(matchstr(definition[-1], '^ *'))
            " remove leading address in front of each line
            let code = map(code, { i,v -> v[leading_address : -1] })
            " FIXME:
            " what's the point?
            call map(code, { i,v -> v ==# ' ' ? '' : v })

            let body = []
            let offset = 0
            for line in readfile(filename)
                " FIXME:
                " handle continuation lines
                " how does our plugin handle them?
                if line =~# '^\s*\\' && !empty(body)
                    let body[-1][0] .= s:sub(line, '^\s*\\', '')
                    " the address of a line in a function isn't necessarily
                    " the same as the one in the file
                    "
                    " every continuation line increases the difference between the 2
                    "
                    " `body` is a list of lists
                    " the 1st item of each list is a line of code
                    " the 2nd item is the offset to add to the address of the
                    " line in the function, to get the address of the line in
                    " the file
                    let offset += 1
                else
                    call extend(body, [[ s:gsub(line, '\t', repeat(' ', &tb)), offset ]])
                endif
            endfor

            for j in range(len(body)-len(code)-2)
                if function =~# '^{'
                    let pat = '.*\.'
                elseif function =~# '^<SNR>'
                    let pat = '\%(s:\|<SID>\)'.matchstr(function, '_\zs.*').'\>'
                else
                    let pat = function.'\>'
                endif

                if body[j][0] =~# '\C^\s*fu\%[nction]!\=\s*'.pat
             \ && (body[j + len(code) + 1][0] =~# '\C^\s*endf'
             \ && map(body[j+1 : j+len(code)], { i,v -> v[0] }) ==# code
             \ || pat !~# '\*')
                    let qfl[-1].filename = filename
                    let qfl[-1].lnum = j + body[j][1] + l:lnum + 1
                    break
                endif
            endfor

        endfor
    endfor

    " make sure there's at  least 1 valid entry so that  `:cwindow` opens the qf
    " window; probably not useful here …
    call map(qfl, { i,v -> extend(v, {'valid': 1}) })

    call setqflist(qfl)
    call setqflist([], 'a', { 'title': ':Messages' })
    " necessary to open qf window with `vim-qf` autocmd
    doautocmd QuickFixCmdPost grep
    $
    call search('^[^|]', 'bWc')
endfu

" script_id {{{1

fu! s:script_id(filename) abort
    let filename = fnamemodify(expand(a:filename), ':p')
    for script in debug#scriptnames()
        if script.filename ==# filename
            return +script.text
        endif
    endfor
    return ''
endfu

" scriptnames {{{1

fu! debug#scriptnames() abort
    let lines = split(execute('scriptnames'), '\n')
    let list = []
    for line in lines
        if line =~# ':'
            call add(list, { 'text':     matchstr(line, '\d\+'),
            \                'filename': expand(matchstr(line, ': \zs.*')),
            \              })
        endif
    endfor

    call map(list, { i,v -> extend(v, {'valid': 1}) })
    call setqflist(list)
    call setqflist([], 'a', { 'title': ':Scriptnames'})
    doautocmd QuickFixCmdPost grep
endfu

" sub {{{1

fu! s:sub(str,pat,rep) abort
    return substitute(a:str, '\v\C'.a:pat, a:rep, '')
endfu

" time {{{1

fu! debug#time(cmd, cnt)
    let time = reltime()
    try
        " We could get rid of the if/else/endif, and shorten the code, but we
        " won't do it, because the most usual case is a:cnt = 1. And we want to
        " execute a:cmd as fast as possible (no let,  no while loop), because Ex
        " commands are slow.
        if a:cnt > 1
            let i = 0
            while i < a:cnt
                exe a:cmd
                let i += 1
            endwhile
        else
            exe a:cmd
        endif
    catch
        call my_lib#catch_error()
    finally
        " We clear the screen before displaying the results, to erase the
        " possible messages displayed by the command.
        redraw
        echom matchstr(reltimestr(reltime(time)), '\v.*\..{,3}').' seconds to run :'.a:cmd
    endtry
endfu

fu! debug#vimrc() abort "{{{1
    if !exists('$TMUX')
        return 'echoerr "Only works inside Tmux"'
    endif

    " open a new file to use as a temporary vimrc
    new /tmp/debug_vimrc
    " wipe the buffer when it becomes hidden
    " useful to not have to remove the next buffer-local autocmd
    setl bh=wipe nobl
    " disable automatic saving
    norm [oa
    " make sure the file is empty
    %d_
    " import our current vimrc
    sil 0r $MYVIMRC
    " write the file
    sil update
    " Every time  we'll change  and write  our temporary vimrc,  we want  Vim to
    " start a new Vim  instance, in a new tmux pane, so that  we can begin a new
    " test. We build the necessary tmux command.
    let s:vimrc = {}
    let s:vimrc.cmd  = 'tmux split-window -c /tmp'
    let s:vimrc.cmd .= ' -v -p 50'
    let s:vimrc.cmd .= ' -PF "#D"'
    let s:vimrc.cmd .= ' vim -Nu /tmp/debug_vimrc'

    augroup my_debug_vimrc
        au! * <buffer>
        " start a Vim session sourcing the new temporary vimrc in a tmux pane
        au BufWritePost <buffer> call s:vimrc_act_on_pane(1)
        " Warning:
        " don't call `s:vimrc_act_on_pane()` AFTER destroying `s:vimrc`
        " the function needs this variable
        au BufWipeOut   <buffer> exe 'norm ]oa'
        \|                       call s:vimrc_act_on_pane(0)
        \|                       unlet s:vimrc
        " close pane when we leave (useful if we restart with SPC R)
        au VimLeave * call s:vimrc_act_on_pane(0)
    augroup END
    return ''
endfu

fu! s:vimrc_act_on_pane(open) abort "{{{1
    " if there's already a tmux pane opened to debug Vim, kill it
    if    get(get(s:, 'vimrc', ''), 'pane_id', -1) != -1
    \&&   stridx(system('tmux list-pane -t %'.s:vimrc.pane_id),
    \            "can't find pane %".s:vimrc.pane_id) == -1
        call system('tmux kill-pane -t %'.s:vimrc.pane_id)
    endif
    if a:open
        " open  a tmux  pane, and  start a  Vim instance  with the  new modified
        " minimal vimrc
        let s:vimrc.pane_id = systemlist(s:vimrc.cmd)[0][1:]
    endif
endfu

fu! debug#wrapper(cmd) abort "{{{1
    try
        ToggleEditingCommands 0
        exe 'debug '.a:cmd
    catch
        call my_lib#catch_error()
    finally
        ToggleEditingCommands 1
    endtry
endfu

" zS {{{1

fu! debug#synnames(...) abort
    "                     The syntax element under the cursor is part of
    "                     a group, which can be contained in another one,
    "                     and so on.
    "
    "                     This imbrication of syntax groups can be seen as a stack.
    "                     `synstack()` returns the list of IDs for all syntax groups
    "                     in the stack, at the position given.
    "
    "                     They are sorted from the outermost syntax group, to the innermost.
    "
    "                  ┌─ The last one is what `synID()` returns.
    "                  │
    return reverse(map(synstack(line('.'), col('.')), { i,v -> synIDattr(v, 'name') }))
endfu

fu! debug#synnames_map(count) abort
    if a:count
        let name = get(debug#synnames(), a:count-1, '')
        if !empty(name)
            exe 'syntax list '.name
        endif
    else
        echo join(debug#synnames())
    endif
endfu
