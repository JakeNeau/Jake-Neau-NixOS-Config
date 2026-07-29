# PR review guide command

A new Claude Code slash command, `/pr-review-guide`, that annotates a pull
request through the `gh` CLI to maximize a human reviewer's understanding. It
posts an editable top-level "reviewer's guide" plus optional inline
annotations, and it updates its own prior output in place on re-run.

## Spec

### The change

Add one slash command, `/pr-review-guide`, that reads a pull request and its
diff, investigates the change through read-only subagents, and posts two
artifacts to the PR:

- an **editable top-level guide** (a PR issue comment) with a changelog and an
  ordered review walkthrough; and
- **individually-managed inline annotations** (PR review comments), each on the
  exact spot it explains.

The command optimizes for one thing: a reviewer who does not know the codebase
understands the change quickly. It never asks the reviewer to change anything
and never approves or requests changes on the reviewer's behalf.

### The artifact is a single command file

The deliverable is one markdown file,
`modules/programs/claude-code/config/commands/pr-review-guide.md`. The flake's
`readMarkdown` collector (`modules/programs/claude-code/claude-code.nix:37`)
maps every `config/commands/<name>.md` to `~/.claude/commands/<name>.md`, so the
file becomes the `/pr-review-guide` command after a rebuild. The file body is
the command prompt; the command's whole behavior is prose instructions to the
model, expressed in this repo's command style (see the sibling command
`modules/programs/claude-code/config/commands/writing-review.md`).

No Nix code, no agent, and no skill is added. The command reuses agents and
skills that already exist: `codebase-investigator`, `doc-reader`, and the
`writing` skill (the router that loads the `controlled-writing` policy).

### The two-artifact decision

The command splits its output into two artifact kinds so each re-run is a clean,
idempotent update rather than a pile of duplicate comments:

- The **top-level guide** is one PR issue comment. It carries a hidden marker,
  `<!-- pr-review-guide:base=<sha> -->`, recording the commit it was generated
  against. GitHub preserves HTML comments in the stored comment body but hides
  them in the rendered view, so the marker stays matchable without showing to
  the reviewer. On re-run the command lists the PR's issue comments, finds its
  own by the marker, reads the base SHA, and edits that comment in place.
- Each **inline annotation** is one PR review comment carrying its own hidden
  marker. On re-run the command lists the PR's review comments, matches its own
  by marker, and adds, updates, or deletes only those — never touching a human's
  review thread.

This split is the core mechanic. It lets the guide grow and be refreshed across
many invocations while leaving human review activity untouched.

### Update mode versus full run

The marker on the top-level guide is how the command decides between a full run
and an update:

- **No prior guide found** (marker absent): a full run. Investigate the whole
  diff, draft both sections, and post fresh.
- **Prior guide found**: update mode. Compare `base...head` (three-dot) to find
  what changed since the last invocation. Three-dot compares against the merge
  base, which is correct for the normal incremental-push case where the recorded
  `base` SHA is an ancestor of the new head. After a rebase or force-push the two
  commits diverge and the comparison is unreliable, so fall back to a full
  re-scan of the whole PR diff in that case (see mechanic (f)). Scope
  investigation to the changed hunks. Refresh only the moved hunks' walkthrough
  steps, re-derive the walkthrough ordering and grouping each run, but preserve
  the step content of hunks that did not move. Reconcile inline annotations (add
  new, update changed, delete obsolete). After posting, refresh the marker's base
  SHA to the new head.

**Accepted trade-off.** A hunk can read differently because its surrounding
context changed even when its own lines did not. The command re-derives the
walkthrough structure every run but only re-writes step content for hunks that
actually moved. This is a deliberate middle ground: it avoids rewriting the
whole guide on every push while keeping ordering and grouping current.

### The top-level guide: a fixed preamble, then two sections

The top-level comment body has, in order: the hidden marker, a fixed preamble
(two parts), then the two authored sections. Body order top to bottom:

1. the hidden marker `<!-- pr-review-guide:base=<sha> -->` (an HTML comment at
   the very top, ahead of the visible preamble; GitHub hides it in the rendered
   view);
2. the fixed preamble part 1 (disclaimer);
3. the fixed preamble part 2 (blockquote);
4. Section 1 — Changelog;
5. Section 2 — Review walkthrough.

**Fixed preamble (protected exact text).** The preamble is fixed boilerplate,
not AI-generated. Insert it verbatim on every post and preserve it unchanged on
every update-mode edit. It is **protected exact text**: it is exempt from the
`writing` skill / controlled-English drafting pass and from the controlled-English
verification pass, and an implementer must not "improve", rephrase, reflow, or
correct its spelling. The preamble appears only in the top-level
guide comment, never in an inline annotation.

Part 1 — a short intro/disclaimer paragraph (visible), exactly this text:

```
I am experimenting with making pull request review guides with AI to make the review on your end easier. I have tested and verified this on my own. Please tell me if this made your job easier or harder.
```

Part 2 — immediately below it, a Markdown blockquote (a `>` block, visible in
the rendered comment), exactly this text:

```
> Do not, my friends, become addicted to slop. It will take hold of you, and you will resent its absence!
```

**Section 1 — Changelog.** The overall PR intent in one or two sentences, then
themed bullets, each bullet paired with its rationale. Include a short "What
this does not change" subsection to name what is out of scope and prevent
misreading. Include a short glossary of repo-specific terms only when such terms
appear. Include a Mermaid diagram sparingly — only when the change spans several
interacting parts and a simple, legible picture helps; a map of where the
changed pieces live is the canonical case. GitHub renders Mermaid in comments.

**Section 2 — Review walkthrough.** An ordered, step-by-step checklist that
covers every hunk in the diff. Order the steps foundational-before-dependent,
never in diff order or alphabetical order. Group hunks that share a purpose,
rationale, location logic, or role. Each step makes four things clear: **what**
the hunk does, **why** it does it, **why** it lives in this file or location,
and **how** it fits the larger repo (what it interfaces with and why). Bias the
explanation toward the why-of-location and the cross-codebase interactions,
because that is the context a reviewer without codebase knowledge lacks. Include
a short before/after behavior example only where logic changes. The walkthrough
only enhances understanding; it never requests a change.

### Behavior, in order

The command runs these steps in order. Steps 3, 8, and 9 delegate to subagents
or skills; the rest are direct `gh` work.

1. **Select the PR.** An explicit argument (`$ARGUMENTS`: a PR number, URL, or
   branch) always wins, whoever authored that PR. With no argument, use the PR
   for the current branch, but only when the current user authored it. Ask the
   user whenever selection is unclear: no PR for the branch, the branch's PR was
   authored by someone else, or the argument matches nothing or is ambiguous.
   Never guess. The `codebase-investigator` and `doc-reader` agents read the
   local checkout, so this command assumes the selected PR corresponds to the
   current repository at or near its head. Read local HEAD with
   `git rev-parse HEAD` and compare it against `.headRefOid` from `gh pr view`.
   When the argument names a different repository, or local HEAD differs
   materially from the PR head, ask the user how to proceed rather than
   investigating the wrong code. Note that `git rev-parse` is a `git` call, not a
   `gh` call, so it falls outside `allowed-tools: Bash(gh:*)`; because
   `allowed-tools` is additive rather than a whitelist and read-only `git` is
   sandbox-auto-allowed here, it still runs without a prompt.
2. **Detect a prior run.** Find the command's own prior guide by its marker.
   When found, read the base SHA and enter update mode; otherwise do a full run.
3. **Investigate (read-only).** Do no investigation inline. Dispatch
   `doc-reader` for high-level questions (architecture, how the change fits the
   repo's overall flow — docs are the source of truth for high-level flow) and
   `codebase-investigator` for code-level questions (what a symbol does, its
   callers, why code lives where it does — it returns `file:line` citations).
   Fan both out in parallel for independent questions. In update mode, scope
   investigation to the changed hunks. Change no code. Note that `doc-reader`
   gates on a real docs system existing and reports cleanly when none does, so a
   target PR in a repo without a docs tree yields an empty `doc-reader` result;
   in that case the command relies on `codebase-investigator`.
4. **Draft the guide.** Write all prose to the house controlled-English standard
   from the first sentence by loading the `writing` skill with the `Skill` tool.
   Build the two sections described above.
5. **Add deep links.** Link every walkthrough step to its hunk in the PR. Link
   out to the related unchanged code each hunk touches (definitions, callers,
   interfaces) with commit-pinned permalinks. Cross-link the two sections.
6. **Add inline annotations.** For each changed hunk, judge whether an inline
   note helps the reviewer understand that exact spot. Add one only where it
   earns its place; never annotate the obvious. Anchor each to file and line.
7. **Surface open questions.** Do not include open questions or author decision
   points automatically. Present each candidate to the user one at a time, ask
   whether to include it, and add only approved ones.
8. **Review pass (loop until clean).** Verify completeness (cross-check the
   walkthrough against `gh pr diff`: every hunk in exactly one step, nothing
   skipped, nothing invented), correctness (every load-bearing claim confirmed
   against subagent evidence; re-dispatch `codebase-investigator` or `doc-reader`
   for anything ungrounded), and coherence (order stays
   foundational-before-dependent; each group truly shares its stated rationale).
   Fix and repeat until clean.
9. **Controlled-English verification pass (run exactly once).** Make one final
   pass over all prose to confirm it holds the controlled-English standard, then
   apply corrections. Do not loop.
10. **Confirm, then post or update.** Show the user the finished draft — both
    sections, every inline annotation with its location, and the approved open
    questions — and wait for approval before anything reaches GitHub. On
    approval, a full run posts the top-level comment and the inline annotations;
    update mode edits the existing comment and reconciles the annotation set.
    Refresh the marker's base SHA to head.

### Open concerns (found while grounding, not design changes)

- **The brief's step 9 names a `writing-review` skill; no such skill exists.**
  The repo has a `writing-review` *command*
  (`config/commands/writing-review.md`) and skills `writing`,
  `controlled-writing`, and `receiving-code-review` — but no `writing-review`
  skill. The `writing` skill is the router that loads the `controlled-writing`
  form policy. This spec therefore states step 9 as one final pass against the
  controlled-English standard, reached through the `writing` router, rather than
  through a non-existent skill. The command file must not reference a
  `writing-review` skill.
- **`gh pr comment --edit-last` cannot do marker-based editing.** It edits only
  the authenticated user's *last* comment, not a comment matched by an embedded
  marker. Marker-based edit-in-place therefore requires the REST API
  (list, match the marker, PATCH by comment id), as the Plan specifies.
- **Inline anchors must land inside a changed hunk.** The GitHub review-comment
  API rejects a `line`/`side` outside the diff with HTTP 422. The command must
  anchor each annotation to a line the diff actually changes on the given side.
- **Use `line`, not `position`.** GitHub has deprecated the diff-offset
  `position` field ("closing down; use line instead"). The command uses the
  file-line `line` field (plus `side`, and `start_line`/`start_side` for a
  multi-line range) everywhere.

## Plan

**Goal:** Add one slash-command file, `pr-review-guide.md`, whose prompt body
drives the approved PR-annotation workflow through the `gh` CLI.

**Architecture:** The deliverable is a single markdown command file collected by
the flake's `readMarkdown` and symlinked to `~/.claude/commands/`. Its body is
an ordered prompt that selects a PR, detects its own prior output by a hidden
marker, investigates through `codebase-investigator` and `doc-reader`, drafts a
two-section guide plus inline annotations to the controlled-English standard,
and posts or idempotently updates them through documented `gh` and `gh api`
calls. No Nix, agent, or skill is added.

**Tech stack:** Markdown with Claude Code command frontmatter; the `gh` CLI
(2.96.0 present) and GitHub REST API via `gh api`; the existing
`codebase-investigator` and `doc-reader` agents and the `writing` skill.

**Global constraints:**

- File path: `modules/programs/claude-code/config/commands/pr-review-guide.md`
  (verbatim).
- Frontmatter fields: `description`, `argument-hint: "[pr-number|url|branch]"`,
  `allowed-tools: Bash(gh:*)`, `disable-model-invocation: true`.
- The command has side effects (it posts to a PR), so it must never auto-fire;
  the user invokes it explicitly. This is why `disable-model-invocation: true`.
- All prose in the command body is authored to the house controlled-English
  standard through the `writing` skill.
- Do no investigation inline; delegate to `codebase-investigator` (code-level,
  `file:line`) and `doc-reader` (high-level flow).
- Never approve or request changes on a PR; post only `event=COMMENT` reviews
  and issue comments.
- Wait for explicit user approval before anything reaches GitHub.
- Validation is dry-build only. Never run `switch`, `nr`, `nrr`, `hr`, or
  `nix flake update`.

### File and frontmatter

Create `modules/programs/claude-code/config/commands/pr-review-guide.md` with
this frontmatter:

```markdown
---
description: Annotate a PR with a reviewer's guide and inline notes for a reviewer who doesn't know the codebase
argument-hint: "[pr-number|url|branch]"
allowed-tools: Bash(gh:*)
disable-model-invocation: true
---
```

`description` leads with the primary use, per [[skill:writing-commands]].
`allowed-tools: Bash(gh:*)` pre-approves the command's `gh` calls so it runs
without a permission prompt for each one. `disable-model-invocation: true`
blocks auto-firing.

### Command body structure

The body is the prompt. It opens by stating the goal and the one optimization
(reviewer understanding), takes the target from `$ARGUMENTS`, then walks the ten
ordered behaviors from the Spec. Structure it with a short intro paragraph, a
"Select the PR" section, and a numbered procedure whose steps match the Spec's
behavior list. Each step names its concrete `gh`/`gh api` mechanic from the
subsections below. The body instructs the model to load the `writing` skill
before drafting prose, to delegate all investigation to the two named agents,
and to wait for user approval before posting. The body must not reference a
`writing-review` skill (see Open concerns); state step 9 as a single final
controlled-English pass through the `writing` router.

### gh / gh api mechanics

All mechanics below are confirmed against the GitHub CLI manual and the GitHub
REST API docs (2026). Resolve owner, repo, and head SHA once up front from
`gh pr view` and reuse them.

**(a) PR selection.**

- Resolve the PR and its facts:
  `gh pr view <arg-or-empty> --json number,url,author,headRefName,headRefOid,baseRefName,headRepository,headRepositoryOwner`.
  With no argument, `gh pr view` resolves the PR for the current branch; with an
  argument it accepts a number, URL, or branch.
- Get the current user's login: `gh api user --jq .login`.
- Decision logic:
  - Argument present: use that PR regardless of author.
  - No argument: compare `.author.login` from `gh pr view` against the login
    from `gh api user`. Proceed only when they match.
  - Ask the user (never guess) when: `gh pr view` errors with
    `no pull requests found for branch "<branch>"`, the branch's PR author
    differs from the current user, or the argument is ambiguous or matches
    nothing.
- Derive `{owner}` and `{repo}` for REST calls by parsing the PR `url`
  (`https://github.com/{owner}/{repo}/pull/{number}`); these are the base repo
  where comments post. Use `.headRefOid` as the head commit SHA and
  `.headRepositoryOwner.login`/`.headRepository.name` as the repo that holds the
  changed files, for permalinks to changed hunks.

**(b) Find the prior guide by marker.**

- Embed the marker `<!-- pr-review-guide:base=<sha> -->` in the top-level
  comment body.
- List issue comments and scan bodies for the marker:
  `gh api --paginate repos/{owner}/{repo}/issues/{number}/comments`
  then match a comment whose `.body` contains `pr-review-guide:base=`. Capture
  its `.id` and parse the base SHA from the marker.
- Found → update mode (edit that comment id). Absent → full run.
- Inline annotations use the same pattern against the review-comment list in (e),
  each carrying its own marker, `<!-- pr-review-guide:hunk=<stable-key> -->`.
  The stable key must survive line-number shifts across pushes, so derive it
  from content, not position: the file path plus a short hash of the hunk's
  changed lines (the `+`/`-` lines, excluding context). Never key on the line
  number. Reconciliation in (e) matches an existing annotation to a current
  hunk by this key: equal key means update the body in place, a key with no
  current hunk means delete, a current hunk with no existing key means add. The
  key survives line-number shifts (its purpose) but changes when the hunk's own
  `+`/`-` lines are edited. An edited hunk therefore reconciles as delete-then-add
  — the old annotation is deleted and a fresh one is created, re-anchored to the
  new head commit — not a body-only PATCH. This is the intended outcome; the
  body-only PATCH path applies only when the key is unchanged.

**(c) Build permalinks.**

- Commit-pinned permalink to a range:
  `https://github.com/{owner}/{repo}/blob/{full_commit_sha}/{path}#L{start}-L{end}`
  (single line `#L{n}`). Only a full commit SHA is permanent.
- For a changed hunk, use the head repo owner/name and `.headRefOid`. For
  unchanged code cross-links, pin to the commit that code lives at (base repo at
  its resolved SHA when the reference is on the base side).
- To link a rendered-markdown source line, append `?plain=1` before the anchor.
- Do not use the column-anchor syntax (`#L15C1-...`); it is undocumented.

**(d) Post or patch the top-level comment.**

- Full run — create:
  `gh pr comment <number> --body-file -` (feed the assembled body, including the
  marker, on stdin).
- Update mode — edit in place by comment id:
  `gh api --method PATCH repos/{owner}/{repo}/issues/comments/{comment_id} -F body=@- < body.md`.
  The `@-` stdin magic works only with `-F/--field`, never with `-f/--raw-field`
  (which would set the body to the literal string `@-`). Do not use
  `gh pr comment --edit-last`; it edits only the user's last comment, not the
  marker-matched one.

**(e) Post and reconcile inline review comments.**

- Full run — batch-create all inline annotations in one review:
  `POST /repos/{owner}/{repo}/pulls/{number}/reviews` with `event=COMMENT`,
  a top-level `body`, and a `comments` array of
  `{path, line, side, body}` (add `start_line`/`start_side` for a multi-line
  range). Run it as:
  `gh api --method POST repos/{owner}/{repo}/pulls/{number}/reviews --input -`
  feeding the JSON payload on stdin. `event=COMMENT` never approves or requests
  changes. Each comment `body` embeds its own marker.
- Update mode — reconcile individually:
  - List existing review comments:
    `gh api --paginate repos/{owner}/{repo}/pulls/{number}/comments`; match the
    command's own by marker (`.body`) and read `.id`, `.path`, `.line`, `.side`.
  - Update a changed annotation:
    `gh api --method PATCH repos/{owner}/{repo}/pulls/comments/{comment_id} -F body=@- < note.md`
    (the PATCH path carries no pull number and updates `body` only; `-F`, not
    `-f`, for the stdin body).
  - Delete an obsolete annotation:
    `gh api --method DELETE repos/{owner}/{repo}/pulls/comments/{comment_id}`.
  - Add a new annotation with a single-comment create. `line` is a JSON integer
    and the `body` is multi-line markdown, so pass a JSON payload on stdin
    rather than typed `-f`/`-F` flags:
    `gh api --method POST repos/{owner}/{repo}/pulls/{number}/comments --input -`
    with a JSON object of `{body, commit_id, path, line, side}` (use
    `.headRefOid` for `commit_id`).
- Anchor gotcha: `line`/`start_line` must fall inside a changed hunk on the given
  `side` (`RIGHT` = head/additions, `LEFT` = base/deletions), or GitHub returns
  HTTP 422. Use `line` (file line), never the deprecated `position` (diff
  offset).

**(f) Get the diff and hunks.**

- Full run — the whole PR diff:
  `gh pr diff <number>` prints the unified diff with `@@` hunk headers. There is
  no `--json` form; parse hunk headers from this output, or read `diff_hunk`
  off existing review comments. For structured per-file data use
  `gh pr view --json files`.
- Update mode — the incremental `base...head` (three-dot) diff since the last
  run:
  `gh pr diff` cannot take two arbitrary commits, and a fork PR's head may not
  be fetched locally, so do not rely on a local `git diff`. Use the compare
  endpoint instead:
  `gh api repos/{owner}/{repo}/compare/{base_sha}...{head_sha}` where
  `base_sha` is the marker's recorded SHA and `head_sha` is `.headRefOid`. Its
  `.files[].patch` field carries the per-file hunks changed since the last run.
  Step 3's update-mode investigation scopes to these files and hunks.
- Compare-endpoint limits and the required full-rescan fallback: this endpoint
  caps the file list at 300 files, shown only on the first page; it can return a
  5xx or time out on a very large comparison; and it omits `.patch` for binary
  files. When the compare response is truncated (300-file cap or paginated) or
  errors, do not silently miss changed files — fall back to a full re-scan of the
  whole PR diff (the full-run path above). The rebase/force-push divergence case
  from the update-mode branch uses this same fallback.

### Validation

The command file is inert prose until a rebuild; it cannot be unit-tested. Its
validation is that the flake still evaluates and builds with the new file
tracked. Functional behavior against a live PR is verified manually by the user
after a rebuild and is out of automated scope for this spec.

## Tasks

### Task 1: Author the command file

**Files:**
- Create: `modules/programs/claude-code/config/commands/pr-review-guide.md`

**Interfaces:**
- Produces: the `/pr-review-guide` command. Consumes existing agents
  `codebase-investigator` and `doc-reader` and the `writing` skill.

- [ ] **Step 1: Write the frontmatter.** Create the file with exactly the
  frontmatter block from the Plan (`description`,
  `argument-hint: "[pr-number|url|branch]"`, `allowed-tools: Bash(gh:*)`,
  `disable-model-invocation: true`).

- [ ] **Step 2: Write the intro and PR-selection section.** Open with the goal
  and the single optimization (reviewer understanding, reviewer does not know
  the codebase). Add the "Select the PR" section encoding mechanic (a): the
  `gh pr view --json ...` call, the `gh api user --jq .login` comparison, the
  argument-wins rule, the four "ask the user, never guess" conditions, and the
  local-checkout precondition (the investigation agents read the current
  checkout, so compare `git rev-parse HEAD` against `.headRefOid` and ask the
  user when the argument names a different repository or local HEAD differs
  materially from the PR head; note `git rev-parse` runs outside
  `Bash(gh:*)` but is sandbox-auto-allowed).

- [ ] **Step 3: Write the prior-run detection step.** Encode mechanic (b): the
  `<!-- pr-review-guide:base=<sha> -->` marker, the
  `gh api --paginate .../issues/{number}/comments` list-and-scan, and the
  update-mode-versus-full-run branch, including the accepted context-change
  trade-off from the Spec, and the inline stable-key derivation (file path plus
  a hash of the hunk's changed lines, never the line number) with its
  add/update/delete reconcile semantics.

- [ ] **Step 4: Write the investigation step.** Instruct: do no investigation
  inline; dispatch `doc-reader` for high-level flow questions and
  `codebase-investigator` for code-level questions; fan out in parallel; scope
  to the changed hunks from mechanic (f)'s three-dot compare endpoint in update
  mode, falling back to a full re-scan of the whole PR diff when the compare
  response is truncated, errors, or the base and head have diverged after a
  rebase/force-push; and note that `doc-reader` no-ops in a repo without a docs
  tree, in which case the command relies on `codebase-investigator`; change no
  code.

- [ ] **Step 5: Write the draft-guide step.** Instruct the model to load the
  `writing` skill with the `Skill` tool before writing any prose, then build the
  two sections: Section 1 (changelog: intent, themed bullets with rationale,
  "What this does not change", optional glossary, Mermaid used sparingly) and
  Section 2 (review walkthrough: every hunk in one ordered step,
  foundational-before-dependent, grouped by shared purpose, each step covering
  what/why/why-here/how-it-fits, before/after only where logic changes).

- [ ] **Step 6: Write the deep-links and inline-annotations steps.** Encode
  mechanic (c) for permalinks, the cross-linking rule, and mechanic (e)'s
  anchoring rules for inline annotations (earn-its-place judgment, file+line
  anchor, own marker).

- [ ] **Step 7: Write the open-questions and review-pass steps.** Encode the
  one-at-a-time user-approval rule for open questions; the completeness /
  correctness / coherence review loop against `gh pr diff`; and the single
  controlled-English verification pass through the `writing` router (do not name
  a `writing-review` skill).

- [ ] **Step 8: Write the confirm-and-post step.** Encode: show the full draft
  and wait for user approval before any GitHub write; then mechanics (d) and (e)
  for full-run posting versus update-mode reconciliation; and refreshing the
  marker's base SHA to head. State that reviews use `event=COMMENT` only.

- [ ] **Step 9: Self-review the file against this spec.** Confirm every behavior
  (1–10) and every `gh`/`gh api` mechanic (a–f) appears, no `writing-review`
  skill is referenced, and the prose holds the controlled-English standard.

- [ ] **Step 10: Commit.**

```bash
git add modules/programs/claude-code/config/commands/pr-review-guide.md
git commit -m "Add /pr-review-guide slash command"
```

### Task 2: Validate the flake build

**Files:**
- No new files. Validates the Task 1 file is collected and the flake still
  builds.

**Interfaces:**
- Consumes: the tracked `pr-review-guide.md` from Task 1.

- [ ] **Step 1: Confirm the file is tracked.** Flake eval ignores untracked
  files, so the `git add` in Task 1 must have staged it.

Run: `git status --short modules/programs/claude-code/config/commands/pr-review-guide.md`
Expected: the file shows as staged or committed, not untracked (`??`).

- [ ] **Step 2: Dry-build this host (cedar).** The Nix sandbox blocks the build
  here, so run with the sandbox disabled.

Run: `nix build ".#darwinConfigurations.cedar.system" --no-link`
Expected: the build succeeds. Never run `switch`, `nr`, `nrr`, or
`nix flake update`.

- [ ] **Step 3 (optional cross-check): flake check.**

Run: `nix flake check`
Expected: no evaluation error introduced by the new command file.
