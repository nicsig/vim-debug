vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

def debug#localPlugin#main(args: string) #{{{1
    var splitted_args: list<string> = split(args)
    var kind: string = matchstr(args, '-kind\s\+\zs[^ -]\S*')
    var filetype: string = matchstr(args, '-filetype\s\+\zs[^-]\S*')

    if index(splitted_args, '-kind') == -1 || index(splitted_args, '-filetype') == -1
        var usage: list<string> =<< trim END
            usage:
                DebugLocalPlugin -kind ftplugin -filetype sh
                DebugLocalPlugin -kind indent   -filetype awk
                DebugLocalPlugin -kind syntax   -filetype python

            To get the list of breakpoints, execute:
                breakl

            When you are finished, execute:
                breakd *
        END
        echo join(usage, "\n")
        return
    endif

    if index(['ftplugin', 'indent', 'syntax'], kind) == -1
        echo 'you did not provide a valid kind; choose:  ftplugin, indent, or syntax'
        return
    elseif getcompletion('', 'filetype')->index(filetype) == -1
        echo 'you did not provide a valid filetype'
        return
    endif

    #     breakadd file */ftplugin/c.vim
    #     breakadd file */indent/c.vim
    #     breakadd file */syntax/c.vim
    AddBreakpoints(kind, filetype)

    if kind == 'ftplugin'
        #     breakadd file */ftplugin/c_*.vim
        AddBreakpoints('ftplugin', filetype, 'c_*.vim')
        #     breakadd file */ftplugin/c/*.vim
        AddBreakpoints('ftplugin', filetype, 'c/*.vim')
    elseif kind == 'syntax'
        #     breakadd file */syntax/c_*.vim
        AddBreakpoints('syntax', filetype, 'c/*.vim')
    endif
enddef

def AddBreakpoints(kind: string, filetype: string, glob = '') #{{{1
    var cmd: string
    if glob != ''
        cmd = kind == 'ftplugin' && (glob == 'c_*.vim' || glob == 'c/*.vim')
            ?     'breakadd file */fptlugin/' .. filetype .. glob[1 :]
            : kind == 'syntax'
            ?     'breakadd file */syntax/' .. filetype .. glob[1 :]
            :     ''
    else
        cmd = 'breakadd file */' .. kind .. '/' .. filetype .. '.vim'
    endif

    if cmd == ''
        return
    endif

    echom '[:DebugLocalPlugin] executing:  ' .. cmd
    exe cmd
enddef

def debug#localPlugin#complete(arglead: string, cmdline: string, pos: number): string #{{{1
    var from_dash_to_cursor: string = matchstr(cmdline, '.*\s\zs-.*\%' .. (pos + 1) .. 'c')

    if from_dash_to_cursor =~ '^-filetype\s*\S*$'
        var filetypes: list<string> = getcompletion('', 'filetype')
        return join(filetypes, "\n")

    elseif from_dash_to_cursor =~ '^-kind\s*\S*$'
        var kinds: list<string> = ['ftplugin', 'indent', 'syntax']
        return join(kinds, "\n")

    elseif empty(arglead) || arglead[0] == '-'
        var options: list<string> = ['-kind', '-filetype']
        return join(options, "\n")
    endif

    return ''
enddef

