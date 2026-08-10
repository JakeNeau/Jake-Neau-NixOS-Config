# The `nr` rebuild function

`modules/programs/fish/functions/nr.fish` defines the verified system rebuild
flow. `modules/programs/fish/functions/nrr.fish` calls `nr "Regular update"`.
Both commands activate system and user state. Agents must not run them without
explicit user approval.

## Invocation

```sh
nr [options] [<message>]
nrr
```

| Option | Behavior |
|---|---|
| `-n`, `--no-git` | Skip staging, committing, and pushing. Pulling and the flake input update still run. |
| `-s`, `--staged` | Commit staged changes plus `flake.lock`. Temporarily stash unstaged tracked changes. |
| `-f`, `--full-output` | Show full Git, Nix, and rebuild output. |
| `-l`, `--long "<body>"` | Add an extended commit-description paragraph. Requires a short message. |

`--staged` conflicts with `--no-git`. `--long` also conflicts with `--no-git`.
A body without a short message is invalid.

## Operation order

`nr` runs these steps in order:

1. Reject an unrestored stash from an earlier `nr --staged` run.
2. Stash unstaged tracked changes when `--staged` requires it.
3. Pull the repository.
4. Update every flake input.
5. Stage the selected changes unless `--no-git` is active.
6. Evaluate every NixOS, nix-darwin, and Home Manager output.
7. Build the current host's system output with `--no-link`.
8. Commit and push unless `--no-git` is active.
9. Activate the current host's system configuration.
10. Run `hr` for the invoking user.
11. Restore changes stashed by `--staged`.

The command stops after any failed operation. A failure after the temporary
stash leaves recovery instructions in the error. A later run refuses to proceed
until the user restores that stash.

## Staging modes

The default mode runs `git add -A`. It includes tracked edits, deletions, and
new files.

`--staged` preserves the user's selected index. It stashes unstaged tracked
changes with `--keep-index`, then stages only the updated `flake.lock`. Untracked
files remain outside the commit and Nix ignores them during flake evaluation.
The command restores the stash after system and home activation.

`--no-git` skips all staging, commit, and push operations. It does not skip the
pull, flake update, verification, system activation, or home activation.

## Commit mechanics

With a message, `nr` creates this subject:

```text
<host> Generation <N>: <message>
```

`<N>` is one greater than the current system generation before activation.
`--long "<body>"` adds the body as a second commit-message paragraph.

Without a message, `nr` amends the latest commit. It replaces an existing
generation prefix or prepends one when absent. It preserves the existing commit
body and pushes with `--force-with-lease`.

When an explicit message has no staged changes, `nr` skips the commit and push.
It still completes the rebuild.
