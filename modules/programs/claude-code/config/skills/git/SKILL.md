---
name: git
description: How to work with the git version control system in any project — inspecting the current changes, deriving a concise, descriptive branch name and creating the branch, and writing clear commit messages that follow these projects' conventions (imperative subject, one logical change per commit, never self-attributed). Use when naming or creating a git branch, staging or committing changes, or choosing a commit message — and whenever a project is tracked by git (a `.git` directory) rather than jujutsu. See [[jujutsu]] for the jj equivalent and [[git-vcs]] for the agent that does this for you.
---

# Working with git

**A branch (or commit) name describes what the change *does*, not what files it
touches.** Read the actual diff first, then name it. Keep names short, lowercase,
and hyphenated; never reference yourself.

## Is this a git project?

`git rev-parse --is-inside-work-tree` (or a `.git` directory) confirms git. If a
`.jj` directory is also present the repo is colocated and jujutsu drives it —
prefer [[jujutsu]] instead.

## Inspect the current changes

| Goal | Command |
| --- | --- |
| What changed, terse | `git status --short` |
| Unstaged diff | `git diff` |
| Staged diff | `git diff --staged` |
| Recent history / naming style | `git log --oneline -n 20` |

## Name a branch from the changes

Derive the name from what the diff accomplishes. Use the form
`<type>/<kebab-summary>`:

- **type** — one of `feat`, `fix`, `refactor`, `docs`, `test`, `chore`.
- **summary** — a few words, lowercase and hyphenated (e.g. `feat/parse-config-flags`).

Create and switch in one step: `git switch -c <name>` (or the older
`git checkout -b <name>`). If you're already on a suitable non-default branch,
say so rather than spawning another.

## Commit conventions

- Imperative, concise subject (~50 chars); add a body only to explain the *why*.
- One coherent, self-contained logical change per commit.
- **Never attribute yourself** — no `Co-Authored-By`, no "Generated with Claude
  Code", no self-reference anywhere in messages, branch names, or tags.
- Don't `push` or do anything outward-facing unless explicitly asked.

## This Nix config repo is special

In `/etc/nixos` and `/etc/nix-darwin`, generation commits use the format
`<host> Generation <N>: <message>` and are made by the `nr` / `nrr` rebuild flow,
which also pushes. **Don't commit or push here yourself** — let the user run the
rebuild. See [[machine-layout]] and [[repo-permissions]].

## Related skills

- [[jujutsu]] — the jujutsu (jj) equivalent of this skill
- [[git-vcs]] — the agent that inspects changes and names/creates a branch for you
- [[repo-permissions]] — write access to the root-owned Nix config repo
- [[machine-layout]] — the Nix machine these projects live on
