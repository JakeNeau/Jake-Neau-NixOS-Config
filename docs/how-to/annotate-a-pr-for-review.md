# Annotate a PR for review

Use `/pr-review-guide` to annotate a GitHub pull request with a reviewer's guide
and inline notes. The guide helps a reviewer who does not know the codebase. Why
the command works this way:
[Why /pr-review-guide posts two markered artifacts](../explanation/pr-review-guide-command.md).

`/pr-review-guide` is a Claude Code slash command, so it is available to the
`jake.neau` agent on cedar. Run it from a checkout of the pull request's
repository. The investigation agents read the local checkout.

## Prerequisites

- Authenticate the `gh` CLI once with `gh auth login`. The command runs every
  GitHub operation through `gh`.
- Check out the repository the pull request targets. Keep local HEAD at or near
  the pull request head. The command asks you how to proceed when the argument
  names a different repository, or when local HEAD differs materially from the
  pull request head.

## Run the command

Give a pull request as an optional argument:

```text
/pr-review-guide [pr-number|url|branch]
```

- With an argument, the command uses that pull request, whoever authored it. The
  argument accepts a pull request number, a URL, or a branch.
- With no argument, the command uses the pull request for the current branch,
  but only when you authored it.

The command asks you, and never guesses, in these cases:

- No pull request exists for the branch.
- Someone else authored the branch's pull request.
- The argument is ambiguous or matches nothing.

## Approve before it posts

The command investigates the diff and drafts the guide and the inline
annotations. It surfaces each open question one at a time for you to include or
drop. It then shows you the finished draft: both sections, every inline
annotation with its location, and the approved questions. Nothing reaches GitHub
until you approve.
On approval it posts one editable top-level guide comment and the inline review
comments. It never approves the pull request and never requests changes.

## Re-run after new commits

Run the command again on the same pull request after new commits. It finds its
own prior guide by a hidden marker and updates it in place. It reconciles the
inline annotations: it adds new ones, updates changed ones, and deletes obsolete
ones. It never touches a human's review threads, and a re-run creates no
duplicate comments.

The guide opens with a preamble: a fixed transparency disclaimer and a wry
"slop"-swapped movie quote drawn from a small pool. The command picks the quote
at random only on the first run. A re-run keeps whatever quote the guide already
holds, so you see the same one on every push, not a new one.
