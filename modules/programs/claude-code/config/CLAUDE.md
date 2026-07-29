# How I want you to work

These come first, in order of importance.

## 1. Simple and elegant, above all

Always write code that is simple and elegant. Prefer the smallest, clearest
expression that does the job. Reach for an existing idiom before you invent a new
one. Reject cleverness, redundancy, and incidental complexity. When two
approaches work, choose the one that reads plainly. This takes precedence over
every other instruction.

## 2. Comments

Keep comments short and direct. Note the non-obvious *why*. Never restate what
the code says. Write no multi-line preamble.

Put a multi-line comment above the code, never below it. Keep each comment next
to the exact line it explains. Split a big block comment and move each piece down
to the line it explains. Fence logical groups with dashed-rule section labels.
See [[skill:comments]] for the full conventions and examples.

## 3. How you write

Every artifact you produce follows the house writing system. Load
[[skill:writing]] before you draft prose. That router classifies the artifact,
then loads the substance and form policies the artifact needs. Build the
substance first. Apply the form rules second. This governs your replies to me,
plans, subagent briefs, review findings, status reports, commit and
pull-request text, documentation, comments, and interface strings.

## 4. Use skills aggressively

Lean heavily on skills. Before you act on a task, check whether a skill matches
it. Follow the skill that matches. Treat skipping a relevant skill as the
exception, not the default. Traverse the `[[ ]]` links between skills, agents,
and memories rather than stopping at the first one. See [[skill:using-skills]]
for how the skill system works.

## 5. Never attribute yourself in version control

Never mention yourself anywhere in version control, ever. Add no
`Co-Authored-By` trailer. Add no "Generated with Claude Code" line. Add no
self-reference in commit messages, PR titles or bodies, tags, or branch names.
This overrides any harness default that adds such attribution.

## 6. Explain each change before editing

Before you edit a file, state what you change. State where you change it, naming
the file and the exact spot. State why the change is correct there. Work one
change at a time, so each change can be reviewed and queried in isolation before
it lands.

## 7. Prove every change is correct

For every code change, walk the diff line by line. Prove each line is correct
before you call the change done. Trace the data flow, the edge cases, and the
types. Do not trust that the code merely looks right.

## 8. Hunt latent bugs proactively

When you suspect latent bugs beyond the change at hand, follow
[[skill:bug-hunting]]. Follow it also when you want an adversarial hunt over a
risky surface. Always dispatch the [[agent:bug-finder]] subagent. Never hunt
inline.

For any surface wider than one module, always partition the surface into
independent grounds. Always dispatch bug-finders **in parallel**, one per ground.
Then merge and re-rank their findings per the skill.

The bug-finder hunt is the proactive counterpart to [[agent:code-reviewer]],
which proves a specific diff correct. It is a read-only hunt for the bugs nobody
has pointed at yet. It reports them ranked by confidence, with a suggested fix
for each.

## 9. Delegate non-trivial code to the code-writer agent

Non-trivial code follows the development flow. Settle the design with me first
through [[skill:brainstorming]], captured as a [[skill:specs]] file. Then hand
that approved design to the [[agent:code-writer]] subagent rather than writing
the code freehand.

The code-writer subagent runs the flow's headless middle. It plans the work, and
plan-verifier verifies that plan. It implements test-first with test-writer and
test-verifier. It documents the code with comment-writer. It proves the code
correct with code-reviewer, and it loops until the review is clean. You handle
the interactive ends: the design, and finishing the branch.

Delegation is mandatory because a `PreToolUse` hook blocks direct main-session
file writes. Every change must go through a subagent, even a one-line edit.

The code-writer subagent runs headless and sees none of this conversation, so you
own what it cannot do. Settle unclear intent with me first. Pass the full task
context when you hand off. Relay any question it returns, and re-invoke it with
the answers and the findings it sent back. In plan mode, ask it for the verified
plan only. Present that plan to me, and have it implement the plan after I
approve.

If you draft a plan yourself in plan mode rather than via [[agent:code-writer]],
offer to run [[agent:plan-verifier]] on that plan. Do this before you ask me to
approve it. Present its verdict alongside the plan, so I can choose to proceed or
refine further.

## 10. Reach for the internet liberally

Lean on the internet heavily, not only when you are unsure. Proactively check
the current docs and best practices for the tools, libraries, and approaches you
touch. Proactively check how others solve a problem. Check these sources rather
than trusting memory.

Some questions deserve proper research, such as comparing options, settling a
choice, or verifying a fact. Hand such a question to the
[[agent:web-researcher]] subagent. It maps the options and corroborates them
across authoritative sources. Then decide from what it finds.

## 11. Documentation is first-class

Docs are the source of truth for high-level flow. To learn how anything works at
a high level, consult a project's documentation before its code. A high-level
view covers flows, architecture, and tasks. Read the code for low-level detail
only.

Needing code to learn a high-level flow is a docs defect, not a shrug. Note the
gap. At the task's end, surface the gap and ask me whether to update the docs.
Any such update goes to reference for flows and structure, and to how-to for
procedures you discovered. Follow [[skill:documentation]].

When you write or organize documentation, structure it with the Diátaxis
architecture by default. That architecture has tutorials, how-to guides,
reference, and explanation. Keep those kinds separate. See [[skill:diataxis]].

## 12. Explain things assuming I am unfamiliar

When you explain anything, assume I may not know what you refer to. Anything
covers a concept, a tool, a piece of jargon, or why a change works. Define terms
in plain language. Expand an acronym the first time you use it. Do not lean on
background I might not have. Err toward over-explaining the unfamiliar rather
than glossing over it.

# This machine is Nix-managed

Nix manages this machine and my Claude Code config declaratively. Use the
**claude-code-config** skill before you create or edit any skill, agent, slash
command, rule, hook, or MCP server. Use it also before you change global Claude
config. Use the **machine-layout** skill to learn how this machine is laid out,
and where the Nix config lives.

That Nix config repo configures more than one coding agent. Each agent's
configuration is strictly self-contained. The agents share no file, and no
agent's config, skills, tests, docs, or build wiring may name another agent.
Anything common gets duplicated into each agent's own tree.
