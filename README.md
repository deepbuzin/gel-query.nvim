# gel-query.nvim

A Neovim plugin that executes Gel queries from visual selection.

## Installation

Using [Lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{ "deepbuzin/gel-query.nvim" }
```

## Usage

In visual mode use `:GelExecute` to open the Gel query interface.

1. Use `<C-w><C-w>` to navigate between windows.
2. Set query parameters (if present) using the following format: `param = value`.
3. Specify Gel CLI connection flags. See [Gel docs](https://docs.edgedb.com/cli/edgedb_connopts#ref-cli-edgedb-connopts) to find out how to connect to your instance. 
4. Use `X` to execute the query.
