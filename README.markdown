# dotenv.vim

This plugin provides basic support for `.env` and `Procfile`.

## Interactive Usage

Use `:Dotenv {file}` or `:Dotenv {dir}` to load a `.env` file and set the
corresponding environment variables in Vim.  Use `:verbose Dotenv` to see what
variables are actually being set.

## Projections

With [projectionist.vim][] and [dispatch.vim][] installed, you'll get a
default `:Start` of `foreman start` for projects with a `Procfile`, and a
default `:Dispatch` of `foreman check` for the `Procfile` itself.

[projectionist.vim]: https://github.com/tpope/vim-projectionist
[dispatch.vim]: https://github.com/tpope/vim-dispatch

## Dispatch

If you call `:Dispatch foreman run whatever` or `:Dispatch dotenv whatever`,
the compiler will be correctly selected for the `whatever` command.

## API

While the above are all marginally helpful, this is the use case that inspired
the plugin.  Other plugins can call `DotenvGet('VAR')` to get the value of
`$VAR` globally or from the current buffer's `.env`.  Here's a wrapper to
optionally use `DotenvGet()` if it's available.

    function! s:env(var) abort
      return exists('*DotenvGet') ? DotenvGet(a:var) : eval('$'.a:var)
    endfunction

    let db_url = s:env('DATABASE_URL')

There's also `DotenvExpand()`, a drop-in replacement for `expand()`.

    function! s:expand(expr) abort
      return exists('*DotenvExpand') ? DotenvExpand(a:expr) : expand(a:expr)
    endfunction

## License

Copyright © Tim Pope.  Distributed under the same terms as Vim itself.
See `:help license`.
