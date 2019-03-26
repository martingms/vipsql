scriptencoding utf-8

if exists('g:loaded_vipsql') || &cp
    finish
endif
let g:loaded_vipsql = 1

if has('nvim')
    let s:env = 'nvim'
else
    if !has('job') || !has('channel') || v:version < 800
        finish
    endif

    let s:env = 'vim'
endif

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

if !exists('g:vipsql_auto_clear_enabled')
    let g:vipsql_auto_clear_enabled = 0
end

if !exists('g:vipsql_separator_enabled')
    let g:vipsql_separator_enabled = 0
end

if !exists('g:vipsql_separator')
    let g:vipsql_separator = '────────────────────'
end

function! s:Show(msg) abort
    echo g:vipsql_log_prefix . a:msg
endfunction

function! s:Log(msg) abort
    echomsg g:vipsql_log_prefix . a:msg
endfunction

function! s:Err(msg) abort
    echoerr g:vipsql_log_prefix . a:msg
endfunction

function! s:OpenSession(...) abort
    if exists('s:session')
        call s:Log('Session already open. Use :VipsqlCloseSession to close it.')
        return
    end

    let l:psql_args = (a:0 > 0) ? a:1 : input('psql .. > ')
    let l:cmd = g:vipsql_psql_cmd . ' ' . l:psql_args

    if !exists('s:bufnr')
        let s:bufnr = s:NewBuffer('__vipsql__')
    end

    exec 'autocmd BufUnload <buffer=' . s:bufnr . '> call s:OutputBufferClosed()'

    let l:job_opts = {
        \'on_output': function('s:OnOutput'),
        \'on_exit': function('s:OnExit'),
    \}

    try
        let s:session = s:JobStart(l:cmd, s:bufnr, l:job_opts)
    catch /vipsql:FailedJobStart/
        call s:Err("Unable to start psql with cmd \"" . l:cmd . "\"")
    endtry
endfunction

function! s:OnOutput(job, data) abort
    " Clear the 'Processing query...' message
    echo ''
endfunction

function! s:OnExit(job, status) abort
    call s:Log('psql exited with code ' . a:status)

    if exists('s:session')
        unlet s:session
    endif
endfunction

function! s:CloseSession() abort
    if !exists('s:session')
        return
    end

    call s:JobStop(s:session)
    unlet s:session
endfunction

function! s:OutputBufferClosed() abort
    call s:CloseSession()
    unlet s:bufnr
endfunction

function! s:Send(text) abort
    if !exists('s:session')
        call s:Log('No open session. Use :VipsqlOpenSession')
        return
    end

    if g:vipsql_separator_enabled
        call s:AppendToBuffer(s:bufnr, ['', g:vipsql_separator, ''])
    end

    if g:vipsql_auto_clear_enabled
        call s:ClearBuffer(s:bufnr)
    end

    call s:Show('Processing query...')
    call s:JobSend(s:session, a:text . "\n")
endfunction

function! s:SendSignal(signal) abort
    try
        call s:JobSignal(s:session, a:signal)
        call s:Log("Signal '" . a:signal . "' sent to psql")
    catch /vipsql:UnsupportedSignal/
        call s:Err("Signal '" . a:signal . "' is unsupported on this platform.")
    endtry
endfunction

function! s:SendRange() range abort
    let l:rv = getreg('"')
    let l:rt = getregtype('"')
    sil exe a:firstline . ',' . a:lastline . 'yank'

    call s:Send(@")
    call setreg('"', l:rv, l:rt)
endfunction

"
" Utils
"

function! s:NewBuffer(name) abort
    " Splits a new buffer from current with given name, goes back to calling
    " buffer and returns bufnr.
    exec 'noswapfile ' . g:vipsql_new_buffer_cmd . ' ' . a:name
    exec g:vipsql_new_buffer_config

    let l:new_bufnr = bufnr('%')

    wincmd p

    return l:new_bufnr
endfunction

function! s:AppendToBuffer(buffer, data) abort
    if len(a:data) == 0
        return
    endif

    if s:env ==# 'vim'
        let l:last_line = getbufline(a:buffer, '$')
        call setbufline(a:buffer, '$', get(l:last_line, 0, '') . a:data[0])
        call appendbufline(a:buffer, '$', a:data[1:])
    elseif s:env ==# 'nvim'
        let l:last_line = nvim_buf_get_lines(a:buffer, -2, -1, 1)
        let l:to_append = [get(l:last_line, 0, '') . a:data[0]] + a:data[1:]
        call nvim_buf_set_lines(a:buffer, -2, -1, 1, l:to_append)
    endif
endfunction

function! s:ClearBuffer(buffer) abort
    if s:env ==# 'vim'
        call deletebufline(a:buffer, 1, '$')
    elseif s:env ==# 'nvim'
        call nvim_buf_set_lines(a:buffer, 0, -1, 1, [])
    endif
endfunction

function! s:GetVisualSelection() abort
    " Taken from http://stackoverflow.com/a/6271254
    " Why is this not a built-in Vim script function?!
    let [l:lnum1, l:col1] = getpos("'<")[1:2]
    let [l:lnum2, l:col2] = getpos("'>")[1:2]

    let l:lines = getline(l:lnum1, l:lnum2)
    let l:lines[-1] = l:lines[-1][: l:col2 - (&selection ==# 'inclusive' ? 1 : 2)]
    let l:lines[0] = l:lines[0][l:col1 - 1:]

    return join(l:lines, "\n")
endfunction

"
" Job control
"

function! s:NvimOutputHandler(opts, jobid, data, event) abort
    call s:AppendToBuffer(s:bufnr, a:data)

    if has_key(a:opts, 'on_output')
        call a:opts.on_output(a:jobid, a:data)
    endif
endfunction

function! s:NvimExitHandler(opts, jobid, status, event) abort
    if has_key(a:opts, 'on_exit')
        call a:opts.on_exit(a:jobid, a:status)
    endif
endfunction

function! s:JobStart(cmd, out_buf, opts) abort
    if s:env ==# 'vim'
        let l:job_opts = {
            \ 'in_io': 'pipe',
            \ 'out_io': 'buffer',
            \ 'err_io': 'buffer',
            \ 'out_buf': a:out_buf,
            \ 'err_buf': a:out_buf,
            \ 'mode': 'raw',
        \}

        if has_key(a:opts, 'on_output')
            let l:job_opts['out_cb'] = a:opts.on_output
            let l:job_opts['err_cb'] = a:opts.on_output
        endif

        if has_key(a:opts, 'on_exit')
            let l:job_opts['exit_cb'] = a:opts.on_exit
        endif

        let l:job = job_start(a:cmd, l:job_opts)

        if job_status(l:job) !=? 'run'
            throw 'vipsql:JobStartFailed'
        endif

    elseif s:env ==# 'nvim'
        let l:job = jobstart(a:cmd, {
            \ 'on_stdout': function('s:NvimOutputHandler', [a:opts]),
            \ 'on_stderr': function('s:NvimOutputHandler', [a:opts]),
            \ 'on_exit': function('s:NvimExitHandler', [a:opts]),
        \})

        if l:job <= 0
            throw 'vipsql:JobStartFailed'
        endif
    endif

    return l:job
endfunction

function! s:JobSend(job, data) abort
    if s:env ==# 'vim'
        call ch_sendraw(job_getchannel(a:job), a:data)
    elseif s:env ==# 'nvim'
        call jobsend(a:job, a:data)
    endif
endfunction

function! s:JobSignal(job, signal) abort
    if s:env ==# 'vim'
        call job_stop(a:job, a:signal)
    elseif s:env ==# 'nvim'
        if a:signal ==# 'term'
            call jobstop(a:job)
        else
            throw 'vipsql:UnsupportedSignal'
        endif
    endif
endfunction

function! s:JobStop(job) abort
    " Will not throw, as both {n,}vim supports SIGTERM
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
