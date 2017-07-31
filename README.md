# vipsql

A vim-plugin for interacting with psql

## Demo

[![asciicast demo](https://asciinema.org/a/HTc1gAS2gHxaL7yCECvwKUUPs.png)](https://asciinema.org/a/HTc1gAS2gHxaL7yCECvwKUUPs)

## Install

### With [Pathogen](https://github.com/tpope/vim-pathogen)

    $ cd ~/.vim/bundle && git clone https://github.com/martingms/vipsql

### As a terminal command

To use vipsql in a manner similar to psql, add something like this to your
`.bashrc` or similar:

    vipsql() {
        vim -c 'setlocal buftype=nofile | setlocal ft=sql | VipsqlOpenSession '"$*"
    }

All args are redirected to the psql session, so e.g.

    $ vipsql -d test

will start vim with vipsql already connected to the database `test`.

### Notes

Note that vipsql uses the vim channels feature, so your vim must be at
least version 8, and compiled with `+channel`. To test whether you're compatible, run:

    $ vim --version | grep -o +channel

If the output is `+channel` you should be good to go.

Please also note that sending an interrupt (`SIGINT`) to psql (for example to
cancel a long running query) results in killing the channel in versions of vim
older than `8.0.0588` due to a bug.

There is currently no support for neovim, and the code is probably horribly
nonidiomatic, but patches accepted :)

## Configure

### Bindings

Put the following in your `.vimrc` (and customize bindings to your liking):

```
" Starts an async psql job, prompting for the psql arguments.
" Also opens a scratch buffer where output from psql is directed.
noremap <leader>po :VipsqlOpenSession<CR>

" Terminates psql (happens automatically if the scratch buffer is closed).
noremap <silent> <leader>pk :VipsqlCloseSession<CR>

" In normal-mode, prompts for input to psql directly.
nnoremap <leader>ps :VipsqlShell<CR>

" In visual-mode, sends the selected text to psql.
vnoremap <leader>ps :VipsqlSendSelection<CR>

" Sends the selected _range_ to psql.
noremap <leader>pr :VipsqlSendRange<CR>

" Sends the current line to psql.
noremap <leader>pl :VipsqlSendCurrentLine<CR>

" Sends the entire current buffer to psql.
noremap <leader>pb :VipsqlSendBuffer<CR>

" Sends `SIGINT` (C-c) to the psql process.
noremap <leader>pc :VipsqlSendInterrupt<CR>
```

### Options

Configuration options (and their defaults) are:

```
" Which command to run to get psql. Should be simply `psql` for most.
let g:vipsql_psql_cmd = "psql"

" The prompt to show when running `:VipsqlShell`
let g:vipsql_shell_prompt = "> "

" What `vim` command to use when opening the scratch buffer
let g:vipsql_new_buffer_cmd = "rightbelow split"
```

## License

Copyright (c) Martin Gammelsæter. Distributed under the same terms as Vim itself. See `:help license`.
