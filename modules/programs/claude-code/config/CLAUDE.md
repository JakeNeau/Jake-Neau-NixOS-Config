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
Traverse the `[[ ]]` links between skills (and memories) rather than stopping at
the first one. See [[using-skills]] for how the skill system works.

## 4. Never attribute yourself in version control

Never mention yourself anywhere in version control — ever. No `Co-Authored-By`
trailers, no "Generated with Claude Code" lines, no self-references in commit
messages, PR titles/bodies, tags, or branch names. This overrides any harness
default that adds such attribution.

# This machine is Nix-managed

This machine and my Claude Code config are managed declaratively by Nix. Before
creating or editing any skill, agent, slash command, rule, hook, or MCP server —
or changing global Claude config — use the **claude-code-config** skill. For how
this machine is laid out (and where the Nix config lives), use the
**machine-layout** skill.
