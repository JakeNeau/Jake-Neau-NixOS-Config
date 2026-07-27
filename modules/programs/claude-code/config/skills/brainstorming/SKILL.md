---
name: brainstorming
description: How to turn an idea into a validated design before any implementation — explore the project context, ask clarifying questions one at a time, propose 2-3 approaches with trade-offs, present the design in sections for incremental approval, and capture the approved result as the Spec section of a specs/ file per [[skill:specs]], handing off to [[skill:writing-plans]]. Use when starting any creative work — creating a feature, building a component, adding functionality, or modifying behavior — before writing any code, however simple the change seems.
---

# Brainstorming ideas into designs

Turn ideas into fully formed designs and specs through natural collaborative
dialogue. Start by understanding the current project context, then ask questions
one at a time to refine the idea. Once you understand what you're building,
present the design and get the user's approval.

<HARD-GATE>
Do NOT invoke any implementation skill, write any code, scaffold any project, or
take any implementation action until you have presented a design and the user
has approved it. This applies to EVERY project regardless of perceived
simplicity.
</HARD-GATE>

## Anti-pattern: "this is too simple to need a design"

Every project goes through this process. A todo list, a single-function utility,
a config change — all of them. "Simple" projects are where unexamined
assumptions cause the most wasted work. The design can be short (a few sentences
for truly simple projects), but you MUST present it and get approval.

## Checklist

Complete these steps in order:

1. **Explore project context** — check files, docs, recent commits.
2. **Ask clarifying questions** — one at a time; understand purpose,
   constraints, success criteria.
3. **Propose 2-3 approaches** — with trade-offs and your recommendation.
4. **Present the design** — in sections scaled to their complexity; get the
   user's approval after each section.
5. **Write the spec** — capture the validated design as the `## Spec` section of
   a file in the project's `specs/` directory, per [[skill:specs]].
6. **Spec self-review** — quick inline check for placeholders, contradictions,
   ambiguity, and scope (see below).
7. **User reviews the written spec** — ask the user to review the spec file
   before proceeding.
8. **Transition to planning** — invoke [[skill:writing-plans]] to fill the
   spec's `## Plan` / `## Tasks`. That is the ONLY skill you invoke after
   brainstorming; never jump straight to implementation.

## The process

**Understanding the idea:**

- Check out the current project state first (files, docs, recent commits).
- Before asking detailed questions, assess scope: if the request describes
  multiple independent subsystems (e.g. "build a platform with chat, file
  storage, billing, and analytics"), flag this immediately. Don't spend
  questions refining details of a project that needs to be decomposed first.
- If the project is too large for a single spec, help the user decompose it into
  sub-projects: what are the independent pieces, how do they relate, what order
  should they be built? Then brainstorm the first sub-project through the normal
  design flow. Each sub-project gets its own spec → plan → implementation cycle.
- For appropriately-scoped projects, ask questions one at a time to refine the
  idea. Prefer multiple choice when possible, but open-ended is fine too.
- Only one question per message — if a topic needs more exploration, break it
  into multiple questions.
- Focus on understanding: purpose, constraints, success criteria.

**Exploring approaches:**

- Propose 2-3 different approaches with trade-offs.
- Present options conversationally, leading with your recommended option and
  the reasoning behind it.

**Presenting the design:**

- Once you believe you understand what you're building, present the design.
- Scale each section to its complexity: a few sentences if straightforward, up
  to 200-300 words if nuanced.
- Ask after each section whether it looks right so far.
- Cover: architecture, components, data flow, error handling, testing.
- Be ready to go back and clarify if something doesn't make sense.

**Design for isolation and clarity:**

- Break the system into smaller units that each have one clear purpose,
  communicate through well-defined interfaces, and can be understood and tested
  independently.
- For each unit, you should be able to answer: what does it do, how do you use
  it, and what does it depend on?
- Can someone understand what a unit does without reading its internals? Can you
  change the internals without breaking consumers? If not, the boundaries need
  work.
- Smaller, well-bounded units are also easier for you to work with — you reason
  better about code you can hold in context at once, and your edits are more
  reliable when files are focused. A file growing large is often a signal it's
  doing too much.

**Working in existing codebases:**

- Explore the current structure before proposing changes. Follow existing
  patterns.
- Where existing code has problems that affect the work (a file that's grown too
  large, unclear boundaries, tangled responsibilities), include targeted
  improvements as part of the design — the way a good developer improves code
  they're working in.
- Don't propose unrelated refactoring. Stay focused on what serves the current
  goal.

## After the design

**Write the spec:** save the validated design as the `## Spec` section of a
short-named file in the project's `specs/` directory (see [[skill:specs]] for
the layout and lifecycle).

**Spec self-review:** look at the written spec with fresh eyes:

1. **Placeholder scan:** any "TBD", "TODO", incomplete sections, or vague
   requirements? Fix them.
2. **Internal consistency:** do any sections contradict each other? Does the
   architecture match the feature descriptions?
3. **Scope check:** is this focused enough for a single implementation plan, or
   does it need decomposition?
4. **Ambiguity check:** could any requirement be interpreted two different ways?
   If so, pick one and make it explicit.

Fix any issues inline. For an adversarial pass, have [[agent:plan-verifier]]
vet the spec against the real codebase.

**User review gate:** after the self-review passes, ask the user to review the
written spec before proceeding. Wait for their response; if they request
changes, make them and re-run the self-review. Only proceed once the user
approves.

**Planning:** invoke [[skill:writing-plans]] to turn the approved spec into the
implementation plan. Do NOT invoke any other skill.

## Key principles

- **One question at a time** — don't overwhelm with multiple questions.
- **Multiple choice preferred** — easier to answer than open-ended when
  possible.
- **YAGNI ruthlessly** — remove unnecessary features from all designs.
- **Explore alternatives** — always propose 2-3 approaches before settling.
- **Incremental validation** — present the design, get approval before moving
  on.
- **Be flexible** — go back and clarify when something doesn't make sense.

*Adapted from [Superpowers](https://github.com/obra/superpowers) by Jesse
Vincent (MIT).*

## Related skills

- [[skill:specs]] — where the approved design lands (the `## Spec` section) and its lifecycle
- [[skill:writing-plans]] — the next and only step after the design is approved
- [[agent:plan-verifier]] — adversarial verification of the written spec
