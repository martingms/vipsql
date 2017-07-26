```
       _                 _
__   _(_)_ __  ___  __ _| |
\ \ / / | '_ \/ __|/ _` | |
 \ V /| | |_) \__ \ (_| | |
  \_/ |_| .__/|___/\__, |_|
        |_|           |_|

```

## Demo

TODO INSERT SCREENCAST HERE

## Install

Note that `vipsql` uses the vim channels feature, so your vim must be at
least version 8, and compiled with `+channel`. To test whether you're compatible, run:

    $ vim --version | grep -o +channel

If the output is `+channel` you should be good to go.

Please also note that sending an interrupt (`SIGINT`) to `psql` (for example to
cancel a long running query) results in killing the channel in versions of `vim`
older than TODO VERSION due to a bug (fixed in TODO URL).

There is currently no support for neovim, but patches are accepted :)

### With [Pathogen](https://github.com/tpope/pathogen):

    $ git clone yadda yadda TODO

### Manually

    $ wget && unzip TODO

## Configure

### Bindings

Put the following in your `.vimrc` (and customize bindings to your liking):

```
let send_buffer = something;
let send_line = something;
let send_vip = something;
let send_selection = something;
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
