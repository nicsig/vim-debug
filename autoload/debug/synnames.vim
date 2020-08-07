fu debug#synnames#main(count) abort "{{{1
    if a:count
        let name = get(s:synnames(), a:count-1, '')
        if !empty(name)
            exe 'syntax list ' .. name
        endif
    else
        echo s:synnames()->join()
    endif
endfu

fu s:synnames(...) abort "{{{1
    " The syntax  element under  the cursor  is part  of a  group, which  can be
    " contained in another one, and so on.
    "
    " This imbrication  of syntax groups  can be  seen as a  stack. `synstack()`
    " returns  the list  of IDs  for  all syntax  groups  in the  stack, at  the
    " position given.
    "
    " They are sorted from the outermost syntax group, to the innermost.
    "
    " The last one is what `synID()` returns.
    return synstack('.', col('.'))->map('synIDattr(v:val, "name")')->reverse()
endfu

