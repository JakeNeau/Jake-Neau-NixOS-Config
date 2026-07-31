# Why /pr-review-guide posts two markered artifacts

`/pr-review-guide` is a Claude Code slash command. It annotates a GitHub pull
request through the `gh` CLI so a reviewer who does not know the codebase
understands the change quickly. This page explains the design. For the procedure
to run it, see [Annotate a PR for review](../how-to/annotate-a-pr-for-review.md).

## The problem: a re-run must not pile up duplicates

A reviewer's guide is useful only while it matches the current diff. A pull
request grows across many pushes. A naive command would post a fresh comment on
every run and bury the pull request in duplicates. It could also disturb a
human's review threads.

## The two-artifact design

The command splits its output into two artifact kinds:

- an **editable top-level guide**: one pull request issue comment that holds a
  changelog and an ordered review walkthrough.
- **individually-managed inline annotations**: one pull request review comment
  for each annotated spot.

Each re-run updates the command's own prior output in place instead of adding
new comments. The split lets the guide grow and refresh across many invocations
while it leaves every human review thread untouched. This split is the core
mechanic.

## Hidden markers make each re-run idempotent

Each artifact carries a hidden marker. GitHub preserves an HTML comment in the
stored comment body but hides it in the rendered view. A marker therefore stays
matchable without showing to the reviewer.

- The top-level guide carries `<!-- pr-review-guide:base=<sha> -->`. The marker
  records the commit the command generated the guide against. On re-run the command
  lists the pull request's issue comments, finds its own by this marker, and
  edits that comment in place.
- Each inline annotation carries `<!-- pr-review-guide:hunk=<stable-key> -->`.
  On re-run the command lists the pull request's review comments, matches its
  own by this marker, and adds, updates, or deletes only those.

### The inline key comes from content, not position

The inline stable key must survive line-number shifts across pushes. The command
derives it from the file path plus a short hash of the hunk's changed lines. It
never keys on the line number.

Reconciliation then matches an existing annotation
to a current hunk by key. An equal key updates the body in place. A key with no
current hunk deletes the annotation. A current hunk with no key adds one. An edit
to a hunk's own changed lines changes its key, so an edited hunk reconciles as
delete-then-add and re-anchors to the new head commit.

## Update mode versus a full run

The top-level marker decides between a full run and an update:

- **Marker absent**: a full run. The command investigates the whole diff, drafts
  both sections, and posts fresh.
- **Marker found**: update mode. The command compares `base...head` (three-dot,
  against the merge base) to find what changed since the last run, scopes
  investigation to the changed hunks, and refreshes only what moved. After
  posting it advances the marker's base SHA to the new head.

Three-dot compare is correct for the normal incremental-push case, where the
recorded base is an ancestor of the new head. After a rebase or force-push the
two commits diverge and the comparison is unreliable. The command then falls
back to a full re-scan of the whole diff. It uses the same fallback when the
compare response is truncated or errors.

### The accepted trade-off

A hunk can read differently because its surrounding context changed even when
its own lines did not. The command re-derives the walkthrough ordering and
grouping every run but rewrites step content only for hunks that actually moved.
This is a deliberate middle ground. It avoids rewriting the whole guide on every
push while it keeps ordering and grouping current.

## The preamble is protected text

The top-level guide opens with a preamble: a short transparency disclaimer. The
preamble is boilerplate, not generated prose. The command exempts it from the
controlled-English drafting pass and the controlled-English verification pass.
It appears only in the top-level guide, never in an inline annotation.

The disclaimer paragraph is fixed. The command inserts the same text verbatim on
every post.

## What the command reuses, and its limits

The command adds no Nix code, agent, or skill. It reuses parts that already
exist. It delegates all investigation to the `codebase-investigator` and
`doc-reader` agents. It drafts all prose through the `writing` skill.

It waits for explicit user approval before any write reaches GitHub. It posts
only `event=COMMENT` reviews and issue comments. It never approves a pull
request, never requests changes, and never asks the reviewer to change anything.

For where this command sits among the machine's coding agents, see
[the claude-code subsystem](claude-code-config.md) and
[coding agents](coding-agents.md).
