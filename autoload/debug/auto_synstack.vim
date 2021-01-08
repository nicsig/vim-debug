vim9 noclear

if exists('loaded') | finish | endif
var loaded = true

const MINIVIMRC = (getenv('XDG_RUNTIME_VIM') ?? '/tmp') .. '/debug_syntax_plugin.vim'

def debug#auto_synstack#main() #{{{1
    augroup DebugSyntax | au!
        au CursorMoved <buffer> EchoSynstack()
        au BufEnter <buffer> exe 'so ' .. MINIVIMRC
    augroup END

    # open a new file to write our mini syntax plugin
    exe 'new ' .. MINIVIMRC
    setline(1, 'syn clear')
enddef

def EchoSynstack()
    echo synstack('.', col('.'))
        ->map((_, v) => synIDattr(v, 'name'))
        ->reverse()
        ->join()
enddef

