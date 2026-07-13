---
name: jujutsu
description: How to work with the Jujutsu (jj) version control system — its change/bookmark model, inspecting the working copy and the stack of changes, naming a bookmark for the working change, writing a concise description for every proposed change, finding the correct existing change to absorb (squash) new edits into, and isolating risky or parallel work in a separate workspace. Because jj logs every operation, `jj undo` and `jj op log` make almost everything reversible, so you can operate with confidence. Use when a project is tracked by jujutsu (a `.jj` directory), when describing or organizing a stack of jj changes, or when deciding which change new edits belong in. See [[skill:git]] for the git equivalent and [[agent:jujutsu-vcs]] for the agent that does this for you.

---

# Working with jujutsu (jj)

**Operate with confidence: every jj command is logged, and `jj undo` /
`jj op log` reverse almost anything.** So describing, rewriting, and squashing
changes is safe to do directly — there's no detached-HEAD-style footgun.

## The jujutsu model (vs git)

- A **change** has a *stable* change-id and can be re-described or rewritten
  freely; its commit hash updates underneath. The **working copy is itself a
  change**, addressed as `@`.
- **Bookmarks** are jj's named pointers — the equivalent of git branches. Most
  changes are anonymous; you add a bookmark only when you need a name.
- A stack is just a chain of changes; you reorder, split, squash, and re-describe
  them rather than amending one HEAD.

## Inspect

| Goal | Command |
| --- | --- |
| Working-copy status | `jj status` |
| The stack / change-ids | `jj log` |
| Working-copy diff | `jj diff` |
| A specific change's diff | `jj diff -r <change-id>` |
| Full detail of a change | `jj show <change-id>` |

## Name a bookmark from the working change

Describe the working change, then point a bookmark at it:

```
jj describe -m "<concise message>"        # title the working change (@)
jj bookmark create <name> -r @            # or: jj bookmark set <name> -r @
```

Name it from what the change *does*, same conventions as [[skill:git]].

## Describe every proposed change

Walk `jj log`; for each change that lacks a clear description, read its diff and
write one:

```
jj diff -r <change-id>                     # understand what it does
jj describe -r <change-id> -m "<message>"  # name it
```

Derive each message from that change alone — don't lump the whole stack under one
description.

## Put new edits into the correct change

When new edits logically belong to an *existing* change, find it and squash them
in rather than leaving a stray working change:

1. Compare the new edits' files/area against each change's diff (`jj diff -r …`).
2. If one change clearly owns them:
   `jj squash --into <change-id>` (move the working copy's edits into it), or
   `jj squash --from <change-id> --into <change-id>` between two existing changes.
3. If none fits, leave the edits as their own new change and say so — don't force
   a bad home.

## Commit conventions

Same as [[skill:git]]: imperative, concise descriptions, one logical change each, and
**never attribute yourself**. Don't `jj git push` unless explicitly asked.

## Isolating work in a workspace

jj's equivalent of a git worktree is a **workspace** — a second working copy
sharing the same repo. Apply the same judgment as [[skill:git]]:

1. **Detect existing isolation first.** `jj workspace list` shows every
   workspace; if you're already in a non-default one, use it — don't nest.
2. **Prefer the harness's native isolation tooling** when one exists.
3. **Fallback:** `jj workspace add ../<name>` (or a git-ignored `.workspaces/`
   directory inside the repo) creates the workspace with its own working-copy
   change; `jj workspace forget <name>` retires it when done.
4. **Verify a clean baseline** — run the project's test suite in the new
   workspace before changing anything.

When the work is done, integrate and clean up per
[[skill:finishing-a-development-branch]].

## Related skills

- [[skill:git]] — the git equivalent, and the shared commit conventions
- [[skill:finishing-a-development-branch]] — completing the work and cleaning up isolation
- [[agent:jujutsu-vcs]] — the agent that names, describes, and organizes jj changes for you
- [[skill:machine-layout]] — the Nix machine these projects live on
