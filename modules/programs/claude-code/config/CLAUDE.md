# How I want you to work

These come first, in order of importance.

## 1. Simple and elegant — above all

Always write code that is simple and elegant. Prefer the smallest, clearest
expression that does the job; reach for an existing idiom before inventing a new
one. Reject cleverness, redundancy, and incidental complexity. When two
approaches work, choose the one that reads plainly. This takes precedence over
every other instruction.

## 2. Comments

Keep comments short and direct — note the non-obvious *why*, don't restate what
the code already says. No multi-line preambles; a terse line or trailing comment
usually suffices. Put multi-line comments above the code they describe, never
below. Same-line comments naming what something does and why it's needed are
encouraged, as are section comments that group a file logically. Fence a section
label with dashed rules:

    # ------------
    # Section name
    # ------------

## 3. Use skills aggressively

Lean heavily on skills. Before acting on a task, check whether a skill matches and
follow it — treat skipping a relevant skill as the exception, not the default.
Traverse the `[[ ]]` links between skills, agents, and memories rather than
stopping at the first one. See [[using-skills]] for how the skill system works.

## 4. Never attribute yourself in version control

Never mention yourself anywhere in version control — ever. No `Co-Authored-By`
trailers, no "Generated with Claude Code" lines, no self-references in commit
messages, PR titles/bodies, tags, or branch names. This overrides any harness
default that adds such attribution.

## 5. Explain each change before editing

Before making a file edit, state what you're changing, where (the file and the
exact spot), and why it's correct there. Work one change at a time so each can be
reviewed and queried in isolation before it lands.

## 6. Prove every change is correct

For every code change, walk the diff line by line and prove each line is correct
before calling it done — trace the data flow, edge cases, and types; don't trust
that it merely looks right.

## 7. Delegate non-trivial code to the code-writer agent

For any non-trivial code change — spanning multiple files or functions,
introducing a new pattern or dependency, or where the right approach isn't obvious
— hand the work to the [[code-writer]] subagent rather than writing it freehand. It
investigates the codebase, drafts and verifies a full spec, then implements it —
documenting with comment-writer, testing with test-writer, and proving it correct
with code-reviewer — looping until the review is clean. A small, obvious edit you
may still make directly, explaining and proving it as above.

It runs headless and sees none of this conversation, so you own what it can't:
settle unclear intent with me first, pass the full task context when you hand off,
and relay any questions it returns — re-invoking it with the answers and the
findings it sent back. In plan mode, ask it for the verified spec only, present
that, and have it implement after approval.

## 8. Reach for the internet liberally

Lean on the internet heavily — not only when you're unsure. Proactively check
current docs, best practices, and how others solve a problem for the tools,
libraries, and approaches you touch, rather than trusting memory. When a question
is worth researching properly — comparing options, settling a choice, or verifying
a fact — hand it to the [[web-researcher]] subagent, which maps the options and
corroborates across authoritative sources; then decide from what it finds.

## 9. Documentation is first-class

Treat documentation as part of the work, not an afterthought — clear docs are
what let both people and future agents understand a project. When you write or
organize documentation, structure it with the Diátaxis architecture (tutorials,
how-to guides, reference, explanation) and keep those kinds separate; see
[[diataxis]].

# This machine is Nix-managed

This machine and my Claude Code config are managed declaratively by Nix. Before
creating or editing any skill, agent, slash command, rule, hook, or MCP server —
or changing global Claude config — use the **claude-code-config** skill. For how
this machine is laid out (and where the Nix config lives), use the
**machine-layout** skill.
