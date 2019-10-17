if exists('b:did_ftplugin')
    finish
endif

runtime! ftplugin/markdown.vim
unlet! b:did_ftplugin

let b:title_like_in_markdown = 1

setl bh=delete bt=nofile fdl=99 wfw

nno <buffer><expr><nowait><silent> q reg_recording() isnot# '' ? 'q' : ':<c-u>q<cr>'
nno <buffer><nowait><silent> R :<c-u>e<cr>

let b:did_ftplugin = 1

" teardown {{{1

let b:undo_ftplugin = get(b:, 'undo_ftplugin', 'exe')
    \ ..'
    \ | setl bh< bt< fdl< wfw<
    \ | unlet! b:title_like_in_markdown
    \ | exe "nunmap <buffer> q"
    \ | exe "nunmap <buffer> R"
    \ '

