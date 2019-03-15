if exists('g:loaded_vipsql') || &cp || !(has('nvim') || has('channel'))
    finish
endif
let g:loaded_vipsql = 1

"
" Config
"

if !exists('g:vipsql_psql_cmd')
    let g:vipsql_psql_cmd = 'psql'
end

if !exists('g:vipsql_shell_prompt')
    let g:vipsql_shell_prompt = '> '
end

if !exists('g:vipsql_new_buffer_cmd')
    let g:vipsql_new_buffer_cmd = 'rightbelow split'
end

if !exists('g:vipsql_new_buffer_config')
    let g:vipsql_new_buffer_config = 'setlocal buftype=nofile'
end

if !exists('g:vipsql_log_prefix')
    let g:vipsql_log_prefix = 'vipsql: '
end

if !exists('g:vipsql_auto_scroll_enabled')
    " TODO: Can this be retained somehow? Save position on Send, restore on
    " output?
    let g:vipsql_auto_scroll_enabled = 1
end

if !exists('g:vipsql_auto_clear_enabled')
    let g:vipsql_auto_clear_enabled = 0
end

if !exists('g:vipsql_separator_enabled')
    let g:vipsql_separator_enabled = 0
end

if !exists('g:vipsql_separator')
    let g:vipsql_separator = '────────────────────'
end

function! s:Show(msg)
    echo g:vipsql_log_prefix . a:msg
endfunction

function! s:Log(msg)
    echomsg g:vipsql_log_prefix . a:msg
endfunction

function! s:Err(msg)
    echoerr g:vipsql_log_prefix . a:msg
endfunction

function! s:OpenSession(...)
    if exists('s:session')
        call s:Log('Session already open. Use :VipsqlCloseSession to close it.')
        return
    end

    let psql_args = (a:0 > 0) ? a:1 : input('psql .. > ')
    let cmd = g:vipsql_psql_cmd . ' ' . psql_args

    if !exists('s:bufnr')
        let s:bufnr = s:NewBuffer('__vipsql__')
    end

    exec 'autocmd BufUnload <buffer=' . s:bufnr . '> call s:OutputBufferClosed()'

    let job_opts = {
        \'on_stdout': function('s:OnOutput'),
        \'on_stderr': function('s:OnOutput'),
        \'on_exit': function('s:OnExit'),
    \}

    let s:session = s:JobStart(cmd, s:bufnr, job_opts)
endfunction

function! s:OnOutput(job, data)
    " Clear the 'Processing query...' message
    echo ''
endfunction

function! s:OnExit(job, status)
    call s:Log('psql exited with code ' . a:status)

    if exists('s:session')
        unlet s:session
    endif
endfunction

function! s:CloseSession()
    if !exists('s:session')
        return
    end

    call s:JobStop(s:session)
    unlet s:session
endfunction

function! s:OutputBufferClosed()
    call s:CloseSession()
    unlet s:bufnr
endfunction

function! s:Send(text)
    if !exists('s:session')
        call s:Log('No open session. Use :VipsqlOpenSession')
        return
    end

    if g:vipsql_separator_enabled
        call s:AppendToBuffer(s:bufnr, [g:vipsql_separator, ''])
    end

    if g:vipsql_auto_clear_enabled
        call s:ClearBuffer(s:bufnr)
    end

    call s:Show('Processing query...')
    " TODO: Handle possible errors.
    call s:JobSend(s:session, a:text . "\n")
endfunction

function! s:SendSignal(signal)
    " TODO: Fix new error codes etc
    if s:JobSignal(s:session, a:signal) == -2
        call s:Err("Signal '" . a:signal . "' is unsupported on this platform.")
    else
        call s:Log("Signal '" . a:signal . "' sent to psql")
    endif
endfunction

function! s:SendRange() range abort
    let rv = getreg('"')
    let rt = getregtype('"')
    sil exe a:firstline . ',' . a:lastline . 'yank'

    call s:Send(@")
    call setreg('"', rv, rt)
endfunction

"
" Utils
"

function! s:NewBuffer(name)
    " Splits a new buffer from current with given name, goes back to calling
    " buffer and returns bufnr.
    exec 'noswapfile ' . g:vipsql_new_buffer_cmd . ' ' . a:name
    exec g:vipsql_new_buffer_config

    let new_bufnr = bufnr('%')

    wincmd p

    return new_bufnr
endfunction

function! s:AppendToBuffer(buffer, data)
    if has('nvim')
        throw 'TODO'
    else
        call appendbufline(a:buffer, '$', a:data)
    endif
endfunction

function! s:ClearBuffer(buffer)
    if has('nvim')
        throw 'TODO'
    else
        call deletebufline(a:buffer, 1, '$')
    endif
endfunction

function! s:GetVisualSelection()
    " Taken from http://stackoverflow.com/a/6271254
    " Why is this not a built-in Vim script function?!
    let [lnum1, col1] = getpos("'<")[1:2]
    let [lnum2, col2] = getpos("'>")[1:2]

    let lines = getline(lnum1, lnum2)
    let lines[-1] = lines[-1][: col2 - (&selection ==# 'inclusive' ? 1 : 2)]
    let lines[0] = lines[0][col1 - 1:]

    return join(lines, "\n")
endfunction


"
" Job control
"
if !has('nvim') && has('job') && has('channel')
    let s:jobtype = 'vim'
elseif has('nvim')
    let s:jobtype = 'nvim'
endif

function! s:JobStart(cmd, out_buf, opts) abort
    if s:jobtype == 'vim'
        let l:job  = job_start(a:cmd, {
            \ 'in_io': 'pipe',
            \ 'out_io': 'buffer',
            \ 'err_io': 'buffer',
            \ 'out_buf': a:out_buf,
            \ 'err_buf': a:out_buf,
            \ 'out_cb': a:opts.on_stdout,
            \ 'err_cb': a:opts.on_stderr,
            \ 'exit_cb': a:opts.on_exit,
            \ 'mode': 'raw',
        \})

        if job_status(l:job) !=? 'run'
            throw "Unable to start job!"
        endif
    elseif s:jobtype == 'nvim'
        " TODO
        throw "TODO"
        " TODO: on_stdout/on_stderr must first append to buffer, then call the
        " opts.on_stdout!
        "let l:job = jobstart(a:cmd, {
        "    \ 'on_stdout': function('s:on_stdout'),
        "    \ 'on_stderr': function('s:on_stderr'),
        "    \ 'on_exit': a:opts.on_exit,
        "\})

        "if l:job <= 0
        "    throw "Unable to start job!"
        "endif
    endif

    return l:job
endfunction

function! s:JobSend(job, data) abort
    if s:jobtype == 'vim'
        call ch_sendraw(job_getchannel(a:job), a:data)
    elseif s:jobtype == 'nvim'
        " TODO
        "call jobsend(a:job, a:data)
        throw "TODO"
    endif
endfunction

function! s:JobSignal(job, signal) abort
    if s:jobtype == 'vim'
        call job_stop(a:job, a:signal)
    elseif s:jobtype == 'nvim'
        " TODO
        throw "TODO"
        "if a:signal == 'term'
        "    call jobstop(a:jobid)
        "else
        "    throw "TODO: Not supported!"
        "endif
    endif
endfunction

function! s:JobStop(job) abort
    call s:JobSignal(a:job, 'term')
endfunction

" Commands
command -nargs=? VipsqlOpenSession call s:OpenSession(<f-args>)
command VipsqlCloseSession call s:CloseSession()
command -nargs=1 VipsqlSend call s:Send(<args>)
command VipsqlShell call s:Send(input(g:vipsql_shell_prompt))
command VipsqlSendCurrentLine call s:Send(getline("."))
command -range=% VipsqlSendSelection call s:Send(s:GetVisualSelection())
command -range=% VipsqlSendRange <line1>,<line2>call s:SendRange()
command VipsqlSendBuffer call s:Send(join(getline(1, '$'), "\n"))
command VipsqlSendInterrupt call s:SendSignal("int")
