# Neovim git diff keymaps

Every key that opens a codediff.nvim diff in Neovim, and how the branch-base keys
choose what to diff against. All of it is declared in
`modules/programs/nvf/nvf.nix`, which contributes to the
`flake.modules.homeManager.nvf` aspect. `<leader>` is Space. For the reasoning,
see [Neovim git diff](../explanation/neovim-git-diff.md).

## Plugin

Declared as `programs.nvf.settings.vim.lazy.plugins."codediff.nvim"`.

| Setting | Value |
|---|---|
| Package | `codediff-nvim` held at 3.1.4; see [Update manual pins](../how-to/update-manual-pins.md#codediffnvim) |
| Setup | `require("codediff").setup({})` |
| Loads on | the `:CodeDiff` command or any file or project key |
| Environment | `CODEDIFF_WATCHER_NO_AUTO_INSTALL=1`, set by `luaConfigRC.codediffNoWatcherInstall` |

The environment variable stops the explorer view from installing a file watcher,
so it polls for changes instead. The gitsigns `diffThis` and `diffProject`
mappings are `null`, so nvf binds nothing to `<leader>hd` or `<leader>hD`.

## File keys

which-key labels the `<leader>gd` group `Diff (file)`.

| Key | Mode | Runs | Description |
|---|---|---|---|
| `<leader>gdd` | normal | `:CodeDiff file HEAD` | Diff file vs HEAD |
| `<leader>gdh` | normal | `:CodeDiff history %` | File history |
| `<leader>gdh` | visual | `:CodeDiff history` over the selection | History of selected lines |
| `<leader>gdb` | normal | `codediff_vs_base('CodeDiff file')` | Diff file vs branch base |
| `<leader>gdB` | normal | `codediff_vs_base('CodeDiff file', true)` | Diff file vs picked branch |

The visual `<leader>gdh` passes the selected line range to codediff, which shows
that range's history (`git log -L`).

## Project keys

which-key labels the `<leader>gD` group `Diff (project)`.

| Key | Mode | Runs | Description |
|---|---|---|---|
| `<leader>gDd` | normal | `:CodeDiff` | Diff project vs HEAD |
| `<leader>gDs` | normal | `:CodeDiff --staged` | Diff staged |
| `<leader>gDh` | normal | `:CodeDiff history` | Project history |
| `<leader>gDb` | normal | `codediff_vs_base('CodeDiff')` | Diff branch (vs branch base) |
| `<leader>gDB` | normal | `codediff_vs_base('CodeDiff', true)` | Diff branch (vs picked branch) |

## Keys inside a diff

These are codediff's defaults; the config sets none of them.

| Key | Action |
|---|---|
| `]c` / `[c` | next / previous hunk |
| `]f` / `[f` | next / previous file |
| `t` | toggle the layout |
| `q` | close the diff |

## Branch-base selection

The four branch keys call `codediff_vs_base(cmd, pick)`. That function and
`codediff_branch_bases()` are declared in `luaConfigRC.codediffBranchBase`.

### Candidates

`codediff_branch_bases()` lists every ref under `refs/heads` and `refs/remotes`
that does not contain `HEAD` (`git for-each-ref --no-contains HEAD`). It
excludes:

- `refs/remotes/*/<current branch>`
- `refs/remotes/*/HEAD`

Candidates are sorted nearest first. A ref's distance is how many of `HEAD`'s
commits it lacks, which is the behind count of `%(ahead-behind:HEAD)`.

Git runs in the directory of the current buffer's file (`git -C`). If that
directory does not exist (for example a `codediff://` or `term://` buffer), git
runs in Neovim's working directory. A git command that fails adds
no candidates.

### Choosing a base

| Situation | `<leader>gdb`, `<leader>gDb` | `<leader>gdB`, `<leader>gDB` |
|---|---|---|
| On a branch | nearest candidate | picker |
| Detached `HEAD` | picker | picker |
| No candidates | warning `no branch base found` | warning `no branch base found` |

A detached `HEAD` is the usual state in a colocated Jujutsu (jj) repository.

The picker is `vim.ui.select`, which the snacks.nvim picker draws. It lists the
candidates nearest first, with the prompt `Diff against`. If you cancel it, no
diff opens.

With a base chosen, the key runs `<cmd> <base>...`, for example
`:CodeDiff file main...`. The three-dot range diffs the merge base of `<base>`
and `HEAD` against the working tree. Commits made on `<base>` after the fork do
not appear, and uncommitted changes do.

### Limits

- If the current branch has a child branch that forked before the current
  branch's newest commits, the child is the nearest candidate.
  `<leader>gdb` and `<leader>gDb` then diff against the child. Use `<leader>gdB`
  or `<leader>gDB` to pick the intended base.
- A remote copy of the current branch under a different name (local `topic`
  tracking `origin/jake/topic`) is not excluded, so it can be the nearest
  candidate.
- Candidates at the same distance share a fork point only when `HEAD`'s history
  has no merge commits. With merges, tied candidates can fork at different
  points, and which one `<leader>gdb` and `<leader>gDb` use is arbitrary.
- `%(ahead-behind:...)` and `for-each-ref --exclude` need git 2.42 or later. With
  an older git, the `for-each-ref` call fails, and every branch key warns
  `no branch base found`.
