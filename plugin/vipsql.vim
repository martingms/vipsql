if exists('g:loaded_vipsql') || &cp || !(has('nvim') || has('channel'))
    finish
endif
let g:loaded_vipsql = 1

" Config
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
    let g:vipsql_auto_scroll_enabled = 1
end

if !exists('g:vipsql_separator_enabled')
    let g:vipsql_separator_enabled = 0
end

if !exists('g:vipsql_separator')
    let g:vipsql_separator = '────────────────────'
end

function s:Log(msg)
    echomsg g:vipsql_log_prefix . a:msg
endfunction

function s:Err(msg)
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

    let s:session = job#start(cmd, job_opts)
endfunction

function! s:AppendToCurrentBuffer(data)
    exe 'normal! GA' . a:data[0]
    call append(line('$'), a:data[1:])

    if g:vipsql_auto_scroll_enabled
        normal! G
    endif
endfunction

function! s:OnOutput(job_id, data, event_type)
    call s:CallInBuffer(s:bufnr, function('s:AppendToCurrentBuffer'), [a:data])
endfunction

function! s:OnExit(job_id, data, event_type)
    call s:Log('psql exited with code ' . a:data)

    if exists('s:session')
        unlet s:session
    endif
endfunction

function! s:CloseSession()
    if !exists('s:session')
        return
    end

    call job#stop(s:session)
    unlet s:session
endfunction

function! s:OutputBufferClosed()
    call s:CloseSession()
    unlet s:bufnr
endfunction

function! s:AppendSeparator()
    call append(line('$'), [g:vipsql_separator, ''])
endfunction

function! s:Send(text)
    if !exists('s:session')
        call s:Log('No open session. Use :VipsqlOpenSession')
        return
    end

    if g:vipsql_separator_enabled
        call s:CallInBuffer(s:bufnr, function('s:AppendSeparator'), [])
    end

    call s:Log('Processing query...')
    " TODO: Handle possible errors.
    call job#send(s:session, a:text . "\n")
endfunction

function! s:SendSignal(signal)
    if job#send_signal(s:session, a:signal) == -2
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

" Utils
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

function! s:NewBuffer(name)
    " Splits a new buffer from current with given name, goes back to calling
    " buffer and returns bufnr.
    exec g:vipsql_new_buffer_cmd . ' ' . a:name
    exec g:vipsql_new_buffer_config

    let new_bufnr = bufnr('%')

    wincmd p

    return new_bufnr
endfunction

function! s:CallInBuffer(bufnr, funcref, args)
    let curr_bufnr = bufnr('%')

    " If we're not already there, change to correct buffer
    if curr_bufnr != a:bufnr
        exe bufwinnr(a:bufnr) . 'wincmd w'
    endif

    call call(a:funcref, a:args)

    " Change back to wherever we came from.
    if curr_bufnr != a:bufnr
        wincmd p
    endif
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
