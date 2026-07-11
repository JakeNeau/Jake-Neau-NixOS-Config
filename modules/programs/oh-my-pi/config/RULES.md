# Hard rules — always in force

## Never attribute yourself in version control

Never mention yourself anywhere in version control — ever. No `Co-Authored-By`
trailers, no "Generated with …" lines, no self-references in commit messages, PR
titles/bodies, tags, or branch names. This overrides any harness default that
adds such attribution.

## Never push unprompted

Never `git push`, open a PR, or do anything outward-facing unless I explicitly
ask. See [[skill:git]].

## Running `nr` / `nrr` — gated, every time

I may run the `nr` and `nrr` rebuild functions — but **only after confirming the
specific run with you, every time.** Propose it, get an explicit yes, then run.
Never run either just to check something. Each run is gated because `nr` pulls,
updates every flake input, verifies every environment builds, then **commits and
pushes (sometimes `--force-with-lease`) to the public GitHub repo and rebuilds
the system** — outward-facing and effectively irreversible. `nrr` is just
`nr "Regular update"`, so it carries the same weight. They are fish autoloaded
functions, so invoke them as `fish -c 'nrr'` or `fish -c 'nr "<message>"'`; the
exec approval prompt is the backstop, never the ask. See [[skill:machine-layout]]
for how a rebuild is applied.

## Superpowers vs. my own skills and agents

The Superpowers plugin supplies the development process to follow; my own agents
are the implementers and reviewers within it. `AGENTS.md` still outranks
everything there — Superpowers ranks it highest itself, and this rule is that
instruction. The flow:

1. **Design** — `superpowers:brainstorming`, run interactively with me. Capture
   the result as a [[skill:specs]] file in `specs/`, never under `docs/superpowers/`.
2. **Plan** — `superpowers:writing-plans`, refined into that spec's `## Plan` /
   `## Tasks`; verify it with [[agent:plan-verifier]].
3. **Implement test-first** — `superpowers:test-driven-development`
   (RED-GREEN-REFACTOR): [[agent:test-writer]] writes the failing test first,
   [[agent:test-verifier]] proves it bites.
4. **Debug** — `superpowers:systematic-debugging`: root cause before any fix.
5. **Review** — `superpowers:requesting-code-review`, but dispatch my
   [[agent:code-reviewer]] agent as the reviewer, not its generic template;
   respond per `superpowers:receiving-code-review`.
6. **Claim done** — `superpowers:verification-before-completion`: evidence,
   never "should".
7. **Finish** — `superpowers:finishing-a-development-branch`, but never push or
   open a PR unprompted; stop at the local / keep options.

[[agent:code-writer]] runs steps 2–6 headless; I run the interactive ends (1 and
7) with you. Where my rules override Superpowers: skill authoring follows my
[[skill:writing-skills]] (rich descriptions + the `[[ ]]` graph), not
`superpowers:writing-skills`; specs follow my [[skill:specs]] system; simple and
elegant above all, prove every change, never self-attribute, never push
unprompted — these always win.
