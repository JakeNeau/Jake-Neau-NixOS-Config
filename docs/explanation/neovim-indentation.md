# Neovim indentation

Why this configuration layers Neovim's indentation the way it does, and why a
measurement backs each per-language value. `modules/programs/nvf/indent.nix`
declares every setting. For the exact values, see
[Neovim indentation settings](../reference/neovim-indentation.md).

## Two independent questions

Indentation names two separate mechanisms. The first is width and style: how
many columns one indent step takes, and whether the file uses tabs or spaces.
The second is the engine: which mechanism computes where a new line starts.
Neovim uses the first non-empty of `'indentexpr'`, `'lisp'`, `'cindent'`,
`'smartindent'`, and `'autoindent'`. The two questions are configured
separately, so this page treats them separately.

## The precedence ladder

Six layers can set width and style. Each layer speaks only when it has
something to say, so control falls through to the next.

| Layer | Mechanism |
|---|---|
| 1. Modeline | Neovim's `'modeline'` |
| 2. `.editorconfig` | Neovim's built-in support, plus vim-sleuth |
| 3. Detected content | vim-sleuth, from the file and then its neighbors |
| 4. This repository's policy | `g:sleuth_<ft>_defaults` |
| 5. Runtime ftplugins | `$VIMRUNTIME/ftplugin/<ft>` |
| 6. Baseline | nvf `vim.options` |

`.editorconfig` is the keystone, because it is the one declaration both sides of
the system read. Neovim reads it, vim-sleuth reads it, and stylua, shfmt, and
prettier read it. One project file therefore configures the editor and the
formatters together, with no glue code.

The ladder puts a project's own declaration above local policy on purpose.
Matching the file you are editing prevents whitespace noise in another person's
repository. The cost is that effective width varies by file, so one filetype can
indent differently in two projects.

## Why vim-sleuth carries the policy

Layer 4 must override the ftplugins while still losing to `.editorconfig` and to
detection. vim-sleuth already merges declared defaults in exactly that order.
The policy therefore reaches it as `g:sleuth_<ft>_defaults` variables rather
than through an autocommand. Sleuth applies them with `setlocal` after the
ftplugins run, which places the policy on the correct rung by construction.

Sleuth infers the remaining options. A declared `tabstop=8` implies tabs, and a
declared `shiftwidth=2` implies spaces. Sleuth may also express a two-space
policy as `tabstop=2` with `shiftwidth=0`, which is the same effective indent,
because zero means "follow `tabstop`".

## Why the ftplugins stay in charge of their languages

Neovim ships per-language indentation defaults, and this repository treats them
as trustworthy. The policy layer therefore holds only genuine disagreements.
Python, Rust, Java, and Lua have no entry, because their ftplugin values already
match what their formatter produces.

This bounds what "one location" means. `indent.nix` holds this repository's
policy, not a mirror of every language's width. Python's four spaces still come
from `$VIMRUNTIME`. Duplicating an upstream default into the policy layer would
create a second owner for a value nobody disputes.

The four-space baseline also repaired an old incoherence at no cost. Rust's
ftplugin sets `shiftwidth=4` and leaves `tabstop` alone, so the previous
two-space baseline produced a buffer whose indent step and tab width disagreed.

## Engine selection and its two exceptions

Treesitter is the default engine, because it measurably beats Neovim's indent
scripts. The test reindented canonically formatted files with `gg=G` and
bypassed format-on-save. Treesitter changed 0 lines in a 426-line Python file
against the indent script's 60. It changed 2 lines in a 1490-line Go file
against 1121.

Two filetypes opt out through `vim.treesitter.indent.excludes`.

YAML opts out because treesitter cannot get it right. A block sequence under a
mapping key may legally be indented or flush with its key, and real files mix
both styles. The treesitter query adds a level for the mapping pair and for the
sequence item alike, so flush sequences land two columns too deep. YAML is also
whitespace-significant, and `=` reparses text it has just rewritten, so one
wrong line changes the tree for every line below it. On a 22-line workflow file
that collapsed the remainder to column zero. Neovim's own script is imperfect
too, changing 4 lines on the same file, but it degrades instead of cascading.

C and C++ opt out because `'cindent'` is better. On a 527-line file, `'cindent'`
changed 55 lines where treesitter changed 272. Exclusion alone is not enough for
them. Excluding a filetype only leaves `'indentexpr'` empty, and Neovim ships no
C indent script, so `indent.nix` sets `'cindent'` by name. Without that they
would fall to plain `'autoindent'`, which changed 252 lines.

Nix stays on treesitter despite scoring poorly. Its single systematic error
indents the body of alejandra's `}: let` construct one level too deep. alejandra
repairs that on save. The error therefore affects only what appears while typing.

## Formatters read the project, not the buffer

nvf derives width flags from the buffer for stylua, taplo, astyle, and deno. A
command-line flag outranks a tool's own configuration file, so that wiring
overrode the declared style of any repository it touched. A `.stylua.toml`
asking for eight spaces produced two-space output. `indent.nix` restores each
formatter's own arguments, so the tool reads `.stylua.toml`, `.taplo.toml`,
`deno.json`, or `.editorconfig` instead.

Two tools cannot participate, because they accept no width option. Python
therefore uses ruff instead of black. ruff honors `indent-width` and keeps
black-compatible output. JSON uses prettier instead of jsonfmt, which discovers
no configuration file at all. Nix keeps alejandra, which hard-codes two spaces
and accepts no options. The `nix` policy entry pins two spaces to match it.
`TODO.md` tracks evaluating nixfmt as a configurable replacement.

Where a repository declares nothing, each tool falls back to its own default,
and that self-corrects. The first format writes the tool's style, sleuth then
detects that style from the file, and the buffer converges.

## The upstream repair

`indent.nix` contains one block that is a workaround rather than policy. lz.n
registers its lazy-loading autocommands with `once = true`. An autocommand that
deletes itself mid-dispatch truncates the chain that dispatched it.
Filetype detection dispatches `FileType` nested inside `BufReadPost`. For the
filetypes lz.n lazy-loads on, the deletion therefore starves everything
registered after it. Lua kept `GetLuaIndent()` and Markdown had no
`'indentexpr'`. vim-sleuth never ran at all, because its initial run lives on
`BufReadPost`.

The repair reapplies both starved layers once per buffer on `BufEnter`. This
design rejects redispatching `FileType`, because that reruns the ftplugins and
clobbers the width sleuth chose. A fix for `neovim/neovim` issue 25526 retires
the block, and `TODO.md` tracks that removal.

## Accepted trade-offs

- Shell scripts fight shfmt in a repository that declares nothing. The policy
  sets two spaces while shfmt defaults to tabs. Adding an `.editorconfig` to a
  repository you own corrects both sides, because shfmt reads it natively.
- Every policy value is a measurement with a shelf life. A grammar or formatter
  update can invalidate a row, so you must remeasure the values rather than
  assume them.
