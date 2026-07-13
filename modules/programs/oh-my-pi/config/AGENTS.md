# How I want you to work

These come first, in order of importance. The short hard constraints (the
rebuild gate, attribution, pushing) live in `RULES.md` and always apply.

## 1. Simple and elegant — above all

Always write code that is simple and elegant. Prefer the smallest, clearest
expression that does the job; reach for an existing idiom before inventing a new
one. Reject cleverness, redundancy, and incidental complexity. When two
approaches work, choose the one that reads plainly. This takes precedence over
every other instruction.

## 2. Comments

Keep comments short and direct — note the non-obvious *why*, never restate what
the code says. No multi-line preambles. Put multi-line comments above the code,
never below, and keep each comment next to the exact line it explains (split a
big block and move the pieces down). Fence logical groups with dashed-rule
section labels. See [[skill:comments]] for the full conventions and examples.

## 3. Use skills aggressively

Lean heavily on skills. Before acting on a task, check whether a skill matches and
follow it — treat skipping a relevant skill as the exception, not the default.
Traverse the `[[ ]]` links between skills, agents, and memories rather than
stopping at the first one. See [[skill:using-skills]] for how the skill system
works. The development process to follow is the flow map injected at session
start; its entry points ([[skill:brainstorming]], [[skill:writing-plans]],
[[skill:test-driven-development]], …) are shared skills like any other.

## 4. Explain each change before editing

Before making a file edit, state what you're changing, where (the file and the
exact spot), and why it's correct there. Work one change at a time so each can be
reviewed and queried in isolation before it lands.

## 5. Prove every change is correct

For every code change, walk the diff line by line and prove each line is correct
before calling it done — trace the data flow, edge cases, and types; don't trust
that it merely looks right.

## 6. Hunt latent bugs proactively

When you suspect latent bugs beyond the change at hand — or want an adversarial
hunt over a risky surface — dispatch the [[agent:bug-finder]] subagent. It is the
proactive counterpart to [[agent:code-reviewer]] (which proves a specific diff
correct): a read-only hunt for the bugs nobody has pointed at yet, reported ranked
by confidence with a suggested fix for each.

## 7. Delegate non-trivial code to the code-writer agent

Non-trivial code follows the development flow: settle the design with me first —
[[skill:brainstorming]], captured as a [[skill:specs]] file — then hand that
approved design to the [[agent:code-writer]] subagent rather than writing it
freehand. It runs the flow's headless middle: planning the work (verified by
plan-verifier), implementing test-first with test-writer/test-verifier,
documenting with comment-writer, and proving it correct with code-reviewer —
looping until the review is clean. You handle the interactive ends — the
design, and finishing the branch.

It runs headless and sees none of this conversation, so you own what it can't:
settle unclear intent with me first, pass the full task context when you hand off,
and relay any questions it returns — re-invoking it with the answers and the
findings it sent back. When asked only to plan, have it return the verified plan,
present that, and have it implement after approval.

When you draft a plan yourself rather than via [[agent:code-writer]], offer to run
[[agent:plan-verifier]] on it before you ask me to approve — present its verdict
alongside the plan so I can choose to proceed or refine further.

## 8. Reach for the internet liberally

Lean on the internet heavily — not only when you're unsure. Proactively check
current docs, best practices, and how others solve a problem for the tools,
libraries, and approaches you touch, rather than trusting memory. When a question
is worth researching properly — comparing options, settling a choice, or verifying
a fact — hand it to the [[agent:web-researcher]] subagent, which maps the options
and corroborates across authoritative sources; then decide from what it finds.

## 9. Documentation is first-class

Treat documentation as part of the work, not an afterthought — clear docs are
what let both people and future agents understand a project. When you write or
organize documentation, structure it with the Diátaxis architecture (tutorials,
how-to guides, reference, explanation) and keep those kinds separate; see
[[skill:diataxis]].

## 10. Explain things assuming I'm unfamiliar

When you explain anything — a concept, a tool, a piece of jargon, or why a change
works — assume I may not know what you're referring to. Define terms in plain
language, expand acronyms the first time you use them, and don't lean on
background I might not have. Err toward over-explaining the unfamiliar rather
than glossing over it.

# This machine is Nix-managed

This machine — including this coding agent's own global config (this file, the
rules, skills, and agents) — is managed declaratively by Nix. Never edit any of
it in the home directory; change it in the Nix config repo and rebuild. For how
this machine is laid out (and where the Nix config lives), use the
**machine-layout** skill.
