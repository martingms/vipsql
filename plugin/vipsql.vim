if exists('g:loaded_vipsql') || &cp || !has('channel')
    finish
endif
let g:loaded_vipsql = 1

" Config
if !exists("g:vipsql_psql_cmd")
    let g:vipsql_psql_cmd = "psql"
end

if !exists("g:vipsql_shell_prompt")
    let g:vipsql_shell_prompt = "> "
end

if !exists("g:vipsql_new_buffer_cmd")
    let g:vipsql_new_buffer_cmd = "rightbelow split"
end

function! s:OpenSession(...)
    if exists("s:session")
        echo "Session already open. Use :VipsqlCloseSession to close it."
        return
    end

    let psql_args = (a:0 > 0) ? a:1 : input("psql .. > ")

    let cmd = g:vipsql_psql_cmd . " " . psql_args

    if !exists("s:bufnr")
        let s:bufnr = s:NewBuffer("__vipsql__")
    end

    " TODO: Is exec needed here?
    exec "autocmd BufUnload <buffer=" . s:bufnr . "> call s:OutputBufferClosed()"

    let job_opts = {
        \"mode": "raw",
        \"out_io": "buffer",
        \"out_buf": s:bufnr,
        \"err_io": "buffer",
        \"err_buf": s:bufnr,
    \}

    let s:session = job_start(cmd, job_opts)
endfunction

function! s:CloseSession()
    if !exists("s:session")
        return
    end

    call s:SendSignal("term")
    unlet s:session
endfunction

function! s:OutputBufferClosed()
    call s:CloseSession()
    unlet s:bufnr
endfunction

function! s:Send(text)
    if !exists("s:session")
        echo "\nNo open session. Use :VipsqlOpenSession"
        return
    end

    let channel = job_getchannel(s:session)

    if ch_status(channel) == "open"
        call ch_sendraw(channel, a:text . "\n")
    else
        echoerr "Attempted send on a closed channel"
    end
endfunction

function! s:SendSignal(...)
    " Sends SIGTERM if no arguments provided
    call job_stop(s:session, a:1)
    echo "Signal '" . a:1 . "' sent to session"
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
  let lines[-1] = lines[-1][: col2 - (&selection == 'inclusive' ? 1 : 2)]
  let lines[0] = lines[0][col1 - 1:]

  return join(lines, "\n")
endfunction

function! s:NewBuffer(name)
    " Splits a new buffer from current with given name, goes back to calling
    " buffer and returns bufnr.

    exec g:vipsql_new_buffer_cmd . " " . a:name
    setlocal buftype=nofile

    let new_bufnr = bufnr('%')

    wincmd p

    return new_bufnr
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
