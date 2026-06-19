# Superpowers vs. my own skills and agents

The Superpowers plugin injects `using-superpowers` every session and supplies the
development process I now follow. **Adopt its flow**; my own agents are the
implementers and reviewers within it. My CLAUDE.md still outranks everything here —
Superpowers ranks it highest itself, and this rule is that instruction.

## The flow to follow

1. **Design** — `superpowers:brainstorming`, run interactively with me. Capture the
   result as a [[skill:specs]] file in `specs/`, never under `docs/superpowers/`.
2. **Plan** — `superpowers:writing-plans`, refined into that spec's `## Plan` /
   `## Tasks`; verify it with [[agent:plan-verifier]].
3. **Implement test-first** — `superpowers:test-driven-development` (RED-GREEN-REFACTOR):
   [[agent:test-writer]] writes the failing test first, [[agent:test-verifier]] proves it bites.
4. **Debug** — `superpowers:systematic-debugging`: root cause before any fix.
5. **Review** — `superpowers:requesting-code-review`, but dispatch my [[agent:code-reviewer]]
   agent as the reviewer, not its generic template; respond per
   `superpowers:receiving-code-review`.
6. **Claim done** — `superpowers:verification-before-completion`: evidence, never "should".
7. **Isolate / parallelize** — `superpowers:using-git-worktrees`,
   `superpowers:dispatching-parallel-agents`.
8. **Finish** — `superpowers:finishing-a-development-branch`, but **never push or open a
   PR unprompted** ([[skill:git]]); stop at the local / keep options.

[[agent:code-writer]] runs steps 2–6 headless; I run the interactive ends (1 and 8) with you.

## Where my rules override Superpowers

- **Skill authoring** → my [[skill:writing-skills]] (rich descriptions + the `[[ ]]` graph),
  not `superpowers:writing-skills`' triggers-only / TDD-on-skills rule.
- **Specs** → my [[skill:specs]] system: `specs/`, Spec/Plan/Tasks, transient lifecycle —
  never `docs/superpowers/`.
- Simple and elegant above all; prove every change; never self-attribute; never push
  unprompted — these always win.
