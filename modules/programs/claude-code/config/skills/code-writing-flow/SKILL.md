---
name: code-writing-flow
description: The order the code-writing stages run in, and who drives them — plan, then the user's call on the plan, then pseudocode explained section by section, then verify, then code, review, docs, doc review, and the two comment passes. The main session orchestrates; each stage is a subagent that sees only its brief. Covers the two user gates, what to hand each stage, and when to scale the flow down or skip it. Use before implementing any non-trivial code change, and whenever deciding which stage comes next.
---

# The code-writing flow

Non-trivial code is built in stages, in a fixed order, each one a subagent with a
single responsibility. **You — the main session — drive the order.** The stages are
headless: they see only the brief you hand them, never this conversation. Two
points in the flow belong to the user, and only you can reach the user, so those
two are yours to run.

Nothing here is enforced by a blocking hook. The order is a discipline, not a
gate: follow it because skipping a stage costs more than it saves, and scale it
down deliberately when the change is small (see "Scaling down").

## The order

| # | Stage | Agent | Who |
|---|-------|-------|-----|
| 1 | Plan the change from the spec | `plan-writer` | agent |
| 2 | **The user's call on the plan** | — | **you + user** |
| 3 | Write pseudocode | `pseudocode-writer` | agent |
| 4 | **Explain each section to the user** | — | **you + user** |
| 5 | Verify the pseudocode | `pseudocode-verifier` | agent |
| 6 | Write the code | `code-writer` | agent |
| 7 | Review the code | `code-reviewer` | agent |
| 8 | Write the docs, retire the spec | `doc-writer` | agent |
| 9 | Review doc coverage and correctness | `doc-reviewer` | agent |
| 10 | Add the comments, listed one by one | `comment-writer` | agent |
| 11 | Conform every comment to the house style | `comment-style-enforcer` | agent |

The design that feeds stage 1 is settled before the flow starts, through
[[skill:brainstorming]] and captured in a [[skill:specs]] file. Finishing the
branch after stage 11 is [[skill:finishing-a-development-branch]].

## Stage 1 — plan

Hand `plan-writer` the spec (or the approved design), the change to plan, and
anything you already know about the codebase. It fills the spec's `## Plan` and
`## Tasks` with [[skill:writing-plans]] rigor and verifies them with
`plan-verifier` before returning.

Keep the `file:line` facts it reports. Every later stage gets them in its brief,
so nobody re-locates the same code four times.

## Stage 2 — the user's call on the plan (a user gate)

Present the plan to the user and stop. This gate is a real fork, not a rubber
stamp, and their answer decides where you go:

- **Clarify** — they ask what something means. Answer from the plan. Assume they
  have not seen the code (CLAUDE.md §12): define the terms, expand the acronyms,
  and say why each part is there. Then ask again.
- **Extend or modify** — they want something added, cut, or changed. Go **back to
  stage 1** with their instruction and the existing plan; don't patch the plan
  yourself. Then present the new plan and gate again.
- **Proceed** — go to stage 3.

Loop stages 1 and 2 as many times as it takes. An unresolved doubt here is far
cheaper than the same doubt discovered at stage 7.

## Stage 3 — pseudocode

Hand `pseudocode-writer` the approved plan and the `file:line` facts. It returns
the pseudocode in named sections, an explanation per section, and a passage on how
the sections fit together.

## Stage 4 — explain each section (a user gate)

**The user's mental model is the point of this stage.** Walk them through the
pseudocode section by section, in order, using the explanations the stage returned
— what the section does, why it exists, how it connects, and what to look at
closely — then the end-to-end passage. Do not summarize the pseudocode and move on;
do not assume any section is too obvious to cover.

Then invite questions and answer them. If a question exposes a design problem, go
back to stage 1 or stage 3 as the problem warrants, rather than talking past it.
This gate ends when the user says they follow it — not when you have finished
talking.

## Stage 5 — verify the pseudocode

Hand `pseudocode-verifier` the pseudocode *and* the plan it came from. Fix what it
proves — via `pseudocode-writer` for pseudocode defects, back at stage 1 for plan
defects — and re-verify. Where a fix changes what the user was told, re-run
stage 4 for the sections that moved. They approved a design; they should not
discover it changed at review time.

## Stage 6 — write the code

Hand `code-writer` the verified pseudocode, the plan, and the `file:line` facts. It
implements test-first with `test-writer` and returns its evidence. It does not run
the review, docs, or comment stages — those are yours, below.

## Stage 7 — review the code

Hand `code-reviewer` the changes and the facts behind them, so it builds on the
same map but forms its own verdict. Send every proven defect back to `code-writer`
and re-review. Stop after the verdict is clean, or after a couple of rounds make no
further progress — then carry the holdouts honestly rather than looping.

Its comment and doc findings are not for it to fix; carry them into the briefs for
stages 8 and 10.

## Stage 8 — docs, and retiring the spec

Hand `doc-writer` the capabilities that changed and the spec that drove them. It
writes the docs and then retires the consumed spec — the whole file when fully
implemented, the consumed sections when partial (see [[skill:specs]]). It gates
itself on a real docs system; where there is none it writes nothing and leaves the
spec in place. That is correct, and worth telling the user.

## Stage 9 — review the docs

Hand `doc-reviewer` the same capabilities and the pages `doc-writer` touched. It
proves coverage, accuracy, and quadrant placement. Send real gaps back to
`doc-writer`.

## Stage 10 — add the comments

Hand `comment-writer` the files that changed, plus any comment finding from stage
7. It adds section labels and why-comments, and returns **every comment it added as
its own list item**. That list is the input to stage 11, so make sure you have it
before moving on.

## Stage 11 — conform every comment

Hand `comment-style-enforcer` the same files. It rewrites every comment to the
house style ([[skill:comments]]) — why over what, ruthless concision, placement and
proximity — and, importantly, strips any comment that names something the file does
not actually depend on. A reusable module does not depend on its callers, so its
comments must never name them; this pass is where that gets fixed.

## Scaling down

The flow scales; the discipline does not. Match the machinery to the change:

- **A small, obvious change** — the user can ask for `simple-code-writer`, which
  writes the code and stops. That is a deliberate choice they make, not a shortcut
  you take for them.
- **A focused change** — run every stage, but expect each to be short: one
  investigation, a page of plan, a few pseudocode sections.
- **A large or risky change** — the full loop, with parallel investigation and more
  than one review round.

Skipping a stage is a decision worth stating out loud. Say which one you skipped
and why, so the user can disagree.

## Related skills

- [[skill:brainstorming]] — settles the design the flow starts from
- [[skill:specs]] — the file the plan, pseudocode, and tasks live in, and its lifecycle
- [[skill:writing-plans]] — the rigor stage 1 is held to
- [[skill:test-driven-development]] — the cycle stage 6 implements with
- [[skill:comments]] — the style stages 10 and 11 enforce
- [[skill:verification-before-completion]] — evidence, not "should", before calling it done
- [[skill:finishing-a-development-branch]] — what happens after stage 11
