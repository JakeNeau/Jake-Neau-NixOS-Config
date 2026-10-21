# Neovim git diff

Why this configuration reviews changes with codediff.nvim, and how the branch
keys decide what a branch is diffed against. `modules/programs/nvf/nvf.nix`
declares every key and the helper behind them. For the keys and the exact
selection rules, see [Neovim git diff keymaps](../reference/neovim-git-diff.md).

## Why codediff replaces gitsigns' diff

gitsigns diffs through Neovim's built-in vimdiff, which compares one file in a
plain split. codediff.nvim draws a VSCode-style side-by-side diff with a file
explorer, so a whole branch can be reviewed in one view. The gitsigns
`diffThis` and `diffProject` mappings are set to `null`, so codediff owns
diffing. Otherwise nvf would bind its own defaults, and two diff viewers would
compete under different keys.

codediff is held at 3.1.4, one of the few hand pins in this repository.
[The flake machinery](flake-machinery.md#nothing-is-pinned-by-hand) explains
why the pin exists, and [Update manual pins](../how-to/update-manual-pins.md#codediffnvim)
says when to remove it.

## The branch-base problem

Reviewing a branch means diffing it against the point where it began. The
earlier helper always used the trunk: `origin/HEAD`, falling back to `main` or
`master`. That is right for a branch cut from trunk. It is wrong for a stacked
branch, one created on top of another feature branch. `CodeDiff origin/main...`
then diffs from where the whole stack left `main`, so the parent branch's
commits flood the review.

## Git records no parent branch

A git branch is only a pointer to a commit. Nothing in the repository stores
which branch it was created from. The base must therefore be inferred from the
commit graph.

## The nearest fork point

Every local and remote branch that does not contain `HEAD` is a candidate. A
ref that contains `HEAD` already has all of the branch's commits, so a diff from
it would show none of the branch's work.

Each candidate is ranked by how many of `HEAD`'s commits it lacks. Those are the
commits made since the candidate and `HEAD` diverged, so the smallest count marks
the most recent fork point. On a stack, that is the parent branch. The key then
runs a three-dot range, `<base>...`, which diffs from the merge base. Starting
at the nearest fork point means only the branch's own work appears.

The sort happens in Lua rather than in git. git's `--sort=ahead-behind:HEAD`
ranks by the ahead count first, which measures how far the candidate has moved
on since the fork. That count says nothing about where the branch began. When
the parent branch had moved further past the fork than `main` had, git ranked
`main` above it.

## Which refs may be a base

Two kinds of ref are excluded by name. The branch's own remote copy,
`<remote>/<current>` on any remote, lags only by unpushed commits. It would always be nearest,
and the diff would show only unpushed work instead of the branch. A
`refs/remotes/*/HEAD` ref only aliases another ref that is already listed.

Excluding the upstream (`@{u}`) was tried and reverted. A branch created with
`git switch -c topic origin/main` tracks `origin/main`, so excluding the
upstream hid trunk, which was the correct base. `@{push}` was also considered.
Under git's default `push.default=simple`, it resolves only when the remote
branch has the same name as the local one. The name rule already covers that
case, and `@{push}` errors in every other case.

Git cannot tell an upstream that is trunk from an upstream that is a renamed
copy of the branch. The design serves the common case, trunk. A renamed copy,
such as local `topic` tracking `origin/jake/topic`, is an accepted limit.

## Parent and child look alike

The commit graph is symmetric around a fork point. Suppose the current branch
has a child branch that forked before the current branch's newest commits. The
child then lacks only those newest commits, exactly as a parent would, and
nothing in the graph distinguishes the two.

The keys therefore come in two families. The inferred keys take the nearest
candidate, which is right in the common case. The picked keys open a picker as
the escape hatch. The picker lists candidates nearest first, so pressing Enter
accepts the guess, and a correct guess costs only one keystroke.

Inferring the fork point from the reflog, as git-machete does, was considered
and not taken. It reads the reflogs of the other local and remote-tracking
branches to find where the current branch left them, which is more accurate for
branches whose history happened locally. It also costs noticeably more code. A
fresh clone records only branch tips in its reflogs, and reflog entries expire.
The graph alone works for every branch.

## A detached HEAD never guesses

With no current branch name, the own-copy exclusion has nothing to match. The
nearest ref is then likely the branch's own copy, so a detached `HEAD` always
opens the picker. This is a routine path, not an edge case. A detached `HEAD` is
the normal state in a colocated Jujutsu (jj) repository, and this configuration
includes jj.nvim.

## Git runs in the buffer's repository

codediff resolves the repository from the current buffer. File mode uses the
buffer's file, and the explorer tries the buffer before the working directory.
The helper therefore asks git in the buffer's directory and falls back to
Neovim's working directory. Asking the working directory alone could pass a
branch name from one repository to another, as when you edit a submodule file
or a second repository.

## The file watcher

codediff's explorer installs a file watcher into the plugin's own directory.
Under Nix that directory is in the read-only store, so the install fails with an
error before anything downloads.
`CODEDIFF_WATCHER_NO_AUTO_INSTALL=1` skips it, and the explorer uses codediff's
built-in polling fallback instead.

## Accepted trade-offs

- On a linear history, candidates at equal distance share a fork point, so a
  tie does not matter. With merge commits, tied candidates can fork at
  different points, and the inferred keys choose among them arbitrarily.
- A renamed remote copy of the branch can be the nearest candidate. The
  inferred keys then show only unpushed work, and the picked keys reach the
  intended base.
