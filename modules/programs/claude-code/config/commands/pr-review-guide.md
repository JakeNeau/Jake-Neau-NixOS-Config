---
description: Annotate a PR with a reviewer's guide and inline notes for a reviewer who doesn't know the codebase
argument-hint: "[pr-number|url|branch]"
allowed-tools: Bash(gh:*)
disable-model-invocation: true
---

Annotate a pull request so a reviewer who does not know this codebase
understands the change quickly. Optimize for that one thing. Never ask the
reviewer to change anything, and never approve or request changes on their
behalf.

The target PR is:

$ARGUMENTS

You post two artifacts:

- an **editable top-level guide** — one PR issue comment carrying a changelog
  and an ordered review walkthrough; and
- **individually-managed inline annotations** — PR review comments, each on the
  exact spot it explains.

Each artifact carries a hidden marker so a re-run updates your own prior output
in place instead of piling up duplicate comments. The top-level guide records
the commit it was generated against; on re-run you diff against that commit,
refresh only what moved, and leave every human's review activity untouched.

Investigate nothing inline. Delegate all investigation to the
`codebase-investigator` and `doc-reader` agents. Draft all prose to the house
controlled-English standard through the `writing` skill. Wait for explicit user
approval before anything reaches GitHub.

Resolve owner, repo, and head SHA once up front and reuse them throughout.

Run the ten steps below in order.

## 1. Select the PR

An explicit argument always wins, whoever authored that PR. With no argument,
use the PR for the current branch, but only when the current user authored it.

- Resolve the PR and its facts:
  `gh pr view <arg-or-empty> --json number,url,author,headRefName,headRefOid,baseRefName,headRepository,headRepositoryOwner`.
  With no argument, `gh pr view` resolves the PR for the current branch; with an
  argument it accepts a number, URL, or branch.
- Get the current user's login: `gh api user --jq .login`.
- Decide:
  - Argument present: use that PR regardless of author.
  - No argument: compare `.author.login` against the login from `gh api user`.
    Proceed only when they match.
- Ask the user, and never guess, when: `gh pr view` errors with
  `no pull requests found for branch "<branch>"`, the branch's PR author differs
  from the current user, or the argument is ambiguous or matches nothing.
- Derive `{owner}` and `{repo}` for REST calls by parsing the PR `url`
  (`https://github.com/{owner}/{repo}/pull/{number}`). These name the base repo
  where comments post. Use `.headRefOid` as the head commit SHA, and
  `.headRepositoryOwner.login` / `.headRepository.name` as the repo that holds
  the changed files, for permalinks to changed hunks.

The `codebase-investigator` and `doc-reader` agents read the local checkout, so
this command assumes the selected PR corresponds to the current repository at or
near its head. Read local HEAD with `git rev-parse HEAD` and compare it against
`.headRefOid`. When the argument names a different repository, or local HEAD
differs materially from the PR head, ask the user how to proceed rather than
investigating the wrong code. `git rev-parse` is a `git` call, not a `gh` call,
so it falls outside `allowed-tools: Bash(gh:*)`; because `allowed-tools` is
additive rather than a whitelist and read-only `git` is sandbox-auto-allowed
here, it still runs without a prompt.

## 2. Detect a prior run

Find your own prior guide by its marker to decide between a full run and an
update.

- Embed the marker `<!-- pr-review-guide:base=<sha> -->` in the top-level
  comment body. GitHub preserves HTML comments in the stored body but hides them
  in the rendered view, so the marker stays matchable without showing to the
  reviewer.
- List issue comments and scan bodies for the marker:
  `gh api --paginate repos/{owner}/{repo}/issues/{number}/comments`, then match a
  comment whose `.body` contains `pr-review-guide:base=`. Capture its `.id` and
  parse the base SHA from the marker.
- **Absent** → full run. Investigate the whole diff, draft both sections, and
  post fresh.
- **Found** → update mode. Compare `base...head` (three-dot, against the merge
  base) to find what changed since the last invocation. Scope investigation to
  the changed hunks. Re-derive the walkthrough ordering and grouping every run,
  but preserve the step content of hunks that did not move; refresh only the
  moved hunks' steps. Reconcile inline annotations (add new, update changed,
  delete obsolete). After posting, refresh the marker's base SHA to the new head.

**Accepted trade-off.** A hunk can read differently because its surrounding
context changed even when its own lines did not. Re-deriving the walkthrough
structure every run while re-writing step content only for hunks that actually
moved is the deliberate middle ground: it avoids rewriting the whole guide on
every push while keeping ordering and grouping current.

Each inline annotation carries its own marker,
`<!-- pr-review-guide:hunk=<stable-key> -->`. The stable key must survive
line-number shifts across pushes, so derive it from content, not position: the
file path plus a short hash of the hunk's changed lines (the `+`/`-` lines,
excluding context). Never key on the line number. Reconciliation in step 10
matches an existing annotation to a current hunk by this key: equal key means
update the body in place; a key with no current hunk means delete; a current
hunk with no existing key means add. The key survives line-number shifts (its
purpose) but changes when the hunk's own `+`/`-` lines are edited. An edited
hunk therefore reconciles as delete-then-add — the old annotation is deleted and
a fresh one is created, re-anchored to the new head commit — not a body-only
PATCH. That is the intended outcome; the body-only PATCH path applies only when
the key is unchanged.

## 3. Investigate (read-only)

Do no investigation inline. Change no code.

- Dispatch `doc-reader` for high-level questions — architecture, and how the
  change fits the repo's overall flow. Docs are the source of truth for
  high-level flow. `doc-reader` gates on a real docs system existing and reports
  cleanly when none does. A target PR in a repo without a docs tree yields an
  empty `doc-reader` result; in that case rely on `codebase-investigator`.
- Dispatch `codebase-investigator` for code-level questions — what a symbol
  does, its callers, why code lives where it does. It returns `file:line`
  citations.
- Fan both out in parallel for independent questions.
- In update mode, scope investigation to the changed hunks from the compare
  endpoint in step 8's mechanic below.

## 4. Draft the guide

Load the `writing` skill with the `Skill` tool before you write any prose, so
every sentence meets the house controlled-English standard from the first draft.
Then build the two sections.

**Section 1 — Changelog.** State the overall PR intent in one or two sentences,
then give themed bullets, each bullet paired with its rationale. Add a short
"What this does not change" subsection to name what is out of scope and prevent
misreading. Add a short glossary of repo-specific terms only when such terms
appear. Include a Mermaid diagram sparingly — only when the change spans several
interacting parts and a simple, legible picture helps; a map of where the
changed pieces live is the canonical case. GitHub renders Mermaid in comments.

**Section 2 — Review walkthrough.** Give an ordered, step-by-step checklist that
covers every hunk in the diff. Order the steps foundational-before-dependent,
never in diff order or alphabetical order. Group hunks that share a purpose,
rationale, location logic, or role. Each step makes four things clear: **what**
the hunk does, **why** it does it, **why** it lives in this file or location,
and **how** it fits the larger repo (what it interfaces with and why). Bias the
explanation toward the why-of-location and the cross-codebase interactions,
because that is the context a reviewer without codebase knowledge lacks. Include
a short before/after behavior example only where logic changes. The walkthrough
only enhances understanding; it never requests a change.

## 5. Add deep links

- Link every walkthrough step to its hunk in the PR.
- Link out to the related unchanged code each hunk touches — definitions,
  callers, interfaces — with commit-pinned permalinks.
- Cross-link the two sections.

Build permalinks per mechanic (c):

- Commit-pinned range:
  `https://github.com/{owner}/{repo}/blob/{full_commit_sha}/{path}#L{start}-L{end}`
  (single line `#L{n}`). Only a full commit SHA is permanent.
- For a changed hunk, use the head repo owner/name and `.headRefOid`. For
  unchanged-code cross-links, pin to the commit that code lives at (the base repo
  at its resolved SHA when the reference is on the base side).
- To link a rendered-markdown source line, append `?plain=1` before the anchor.
- Do not use the column-anchor syntax (`#L15C1-...`); it is undocumented.

## 6. Add inline annotations

For each changed hunk, judge whether an inline note helps the reviewer
understand that exact spot. Add one only where it earns its place; never
annotate the obvious. Anchor each to file and line, and embed its own
`pr-review-guide:hunk=<stable-key>` marker.

Anchor gotcha: `line` / `start_line` must fall inside a changed hunk on the given
`side` (`RIGHT` = head/additions, `LEFT` = base/deletions), or GitHub returns
HTTP 422. Use `line` (the file line), plus `side`, and `start_line` /
`start_side` for a multi-line range. Never use the deprecated `position` field
(the diff offset); GitHub is closing it down.

## 7. Surface open questions

Do not include open questions or author decision points automatically. Present
each candidate to the user one at a time, ask whether to include it, and add only
approved ones.

## 8. Review pass (loop until clean)

Get the diff and hunks per mechanic (f):

- Full run — the whole PR diff: `gh pr diff <number>` prints the unified diff
  with `@@` hunk headers. There is no `--json` form; parse hunk headers from this
  output, or read `diff_hunk` off existing review comments. For structured
  per-file data use `gh pr view --json files`.
- Update mode — the incremental `base...head` (three-dot) diff since the last
  run: `gh pr diff` cannot take two arbitrary commits, and a fork PR's head may
  not be fetched locally, so do not rely on a local `git diff`. Use the compare
  endpoint: `gh api repos/{owner}/{repo}/compare/{base_sha}...{head_sha}`, where
  `base_sha` is the marker's recorded SHA and `head_sha` is `.headRefOid`. Its
  `.files[].patch` field carries the per-file hunks changed since the last run.
- Compare-endpoint limits and the required full-rescan fallback: the endpoint
  caps the file list at 300 files, shown only on the first page; it can return a
  5xx or time out on a very large comparison; and it omits `.patch` for binary
  files. When the compare response is truncated (300-file cap or paginated) or
  errors, do not silently miss changed files — fall back to a full re-scan of the
  whole PR diff (the full-run path above). Use this same fallback when the
  recorded base and the new head have diverged after a rebase or force-push,
  because three-dot compare is then unreliable.

Then verify, and repeat until clean:

- **Completeness.** Cross-check the walkthrough against `gh pr diff`: every hunk
  in exactly one step, nothing skipped, nothing invented.
- **Correctness.** Confirm every load-bearing claim against subagent evidence;
  re-dispatch `codebase-investigator` or `doc-reader` for anything ungrounded.
- **Coherence.** Order stays foundational-before-dependent; each group truly
  shares its stated rationale.

## 9. Controlled-English verification pass (run exactly once)

Make one final pass over all prose to confirm it holds the controlled-English
standard, reached through the `writing` router, then apply corrections. Do not
loop.

## 10. Confirm, then post or update

Show the user the finished draft — both sections, every inline annotation with
its location, and the approved open questions — and wait for approval before
anything reaches GitHub.

On approval, post `event=COMMENT` reviews and issue comments only. Never approve
or request changes.

**Full run.**

- Create the top-level comment: `gh pr comment <number> --body-file -`, feeding
  the assembled body (including the marker) on stdin.
- Batch-create all inline annotations in one review:
  `gh api --method POST repos/{owner}/{repo}/pulls/{number}/reviews --input -`,
  feeding a JSON payload on stdin with `event=COMMENT`, a top-level `body`, and a
  `comments` array of `{path, line, side, body}` (add `start_line` / `start_side`
  for a multi-line range). Each comment `body` embeds its own marker.

**Update mode.**

- Edit the top-level comment in place by comment id:
  `gh api --method PATCH repos/{owner}/{repo}/issues/comments/{comment_id} -F body=@- < body.md`.
  The `@-` stdin magic works only with `-F` / `--field`, never with `-f` /
  `--raw-field` (which would set the body to the literal string `@-`). Do not use
  `gh pr comment --edit-last`; it edits only your last comment, not the
  marker-matched one.
- List existing review comments:
  `gh api --paginate repos/{owner}/{repo}/pulls/{number}/comments`; match your
  own by marker (`.body`) and read `.id`, `.path`, `.line`, `.side`.
  - Update a changed annotation:
    `gh api --method PATCH repos/{owner}/{repo}/pulls/comments/{comment_id} -F body=@- < note.md`
    (the PATCH path carries no pull number and updates `body` only; `-F`, not
    `-f`, for the stdin body).
  - Delete an obsolete annotation:
    `gh api --method DELETE repos/{owner}/{repo}/pulls/comments/{comment_id}`.
  - Add a new annotation with a single-comment create; `line` is a JSON integer
    and the `body` is multi-line markdown, so pass a JSON payload on stdin rather
    than typed `-f` / `-F` flags:
    `gh api --method POST repos/{owner}/{repo}/pulls/{number}/comments --input -`
    with `{body, commit_id, path, line, side}` (use `.headRefOid` for
    `commit_id`).

After posting, refresh the marker's base SHA to head.

## The top-level guide's preamble

The top-level comment body has, top to bottom: the hidden marker; the preamble
(two parts); Section 1 (Changelog); Section 2 (Review walkthrough).

The preamble is boilerplate, not AI-generated. Whichever text it holds is
**protected exact text**: reproduce it **verbatim**, exempt from the `writing`
skill / controlled-English drafting pass (step 4) and from the controlled-English
verification pass (step 9). Do not improve, rephrase, reflow, or correct its
spelling. The preamble appears only in the top-level guide comment, never in an
inline annotation.

Part 1 — a short intro/disclaimer paragraph (visible), always exactly this text:

```
I am experimenting with making pull request review guides with AI to make the review on your end easier. I have tested and verified this on my own. Please tell me if this made your job easier or harder.
```

Part 2 — immediately below it, a Markdown blockquote (visible in the rendered
comment) holding **one** quote from the pool below. On a first run, pick one
quote at random and vary the choice across invocations. On an update-mode edit,
keep whichever quote the existing comment already holds — never re-roll it.
Reproduce the chosen quote verbatim, including its leading `> `. The pool:

```
> Do not, my friends, become addicted to slop. It will take hold of you, and you will resent its absence!
```

```
> You merely adopted the slop. I was born in it, molded by it.
```
