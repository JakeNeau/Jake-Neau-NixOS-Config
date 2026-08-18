# Neovim indentation settings

Every tab and space setting for Neovim, and where each one is declared. All
values live in `modules/programs/nvf/indent.nix`, which contributes to the
`flake.modules.homeManager.nvf` aspect. For the reasoning, see
[Neovim indentation](../explanation/neovim-indentation.md).

## Baseline

Declared through `programs.nvf.settings.vim.options`. These values apply to any
filetype that has no ftplugin default and no policy entry.

| Option | Value |
|---|---|
| `autoindent` | `true` |
| `expandtab` | `true` |
| `shiftwidth` | `0` |
| `tabstop` | `4` |

A `shiftwidth` of `0` means "use `tabstop`", so `tabstop` sets both the width a
tab renders as and the size of one indent step.

## Per-filetype policy

Declared through `programs.nvf.settings.vim.globals` as
`sleuth_<filetype>_defaults` variables. vim-sleuth applies them after the
runtime ftplugins, and its own detection and any `.editorconfig` override them.

| Filetypes | Declared value | Effective indent |
|---|---|---|
| `nix` | `shiftwidth=2` | 2 spaces |
| `css`, `html`, `javascript`, `json`, `jsonc`, `svelte`, `typescript` | `shiftwidth=2` | 2 spaces |
| `toml` | `shiftwidth=2` | 2 spaces |
| `markdown` | `shiftwidth=2` | 2 spaces |
| `c`, `cpp` | `shiftwidth=2` | 2 spaces |
| `go` | `tabstop=8` | tabs, rendered 8 wide |
| `bash`, `sh` | `shiftwidth=2` | 2 spaces |

Filetypes with no entry take their width from a runtime ftplugin or from the
baseline. Measured results for those: `python` and `rust` use 4 spaces, `yaml`
uses 2 spaces, and `lua` uses the baseline.

## Engine per filetype

Treesitter supplies `'indentexpr'` for every filetype except those listed in
`programs.nvf.settings.vim.treesitter.indent.excludes`.

| Filetype | Engine | Source |
|---|---|---|
| `yaml` | `GetYAMLIndent()` | Neovim runtime indent script |
| `c`, `cpp` | `'cindent'` | set by the `indent_cindent` autocommand |
| all others | `v:lua.require'nvim-treesitter'.indentexpr()` | nvf |

Excluding a filetype leaves `'indentexpr'` empty. For `c` and `cpp`, Neovim
ships no indent script, so `indent.nix` sets `'cindent'` in a `FileType`
autocommand.

## Formatter arguments

Declared through
`programs.nvf.settings.vim.formatter.conform-nvim.setupOpts.formatters`. Four
formatters have their own arguments restored with `lib.mkForce`, which removes
the width flags nvf derives from the buffer.

| Formatter | Restored value |
|---|---|
| `astyle` | `require('conform.formatters.astyle').args` |
| `deno` | `require('conform.formatters.deno_fmt').args` |
| `stylua` | `require('conform.formatters.stylua').args` |
| `taplo` | `require('conform.formatters.taplo').args` |

Formatter selections that differ from the nvf default:

| Filetype | Formatter | Declared in |
|---|---|---|
| `python` | `ruff` | `vim.languages.python.format.type` |
| `json`, `jsonc` | `prettier` | `vim.languages.json.format.type` |

## Detection

`programs.nvf.settings.vim.utility.sleuth.enable` is `true`. vim-sleuth reads a
project's `.editorconfig`, then guesses from the current file, then guesses from
neighboring files of the same filetype. It writes nothing when it finds no
evidence.

## The repair autocommand

`indent.nix` registers a `BufEnter` autocommand in the `indent_repair` group. It
runs once per buffer, guarded by `b:indent_repaired`, and skips buffers with a
non-empty `'buftype'` or an empty `'filetype'`. It sets the treesitter
`'indentexpr'` for non-excluded filetypes and runs `:Sleuth` when `b:sleuth` is
unset. It exists because of `neovim/neovim` issue 25526.

## Inspecting the effective settings

| Command | Reports |
|---|---|
| `:verbose set shiftwidth? tabstop? softtabstop? expandtab?` | the values and the file that last set each one |
| `:verbose set indentexpr?` | the active engine |
| `:Sleuth` | vim-sleuth's detection, applied verbosely |
| `:echo b:sleuth` | the options vim-sleuth resolved, with each source |
