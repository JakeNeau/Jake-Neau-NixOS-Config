---
name: writing-skills
description: How to author a skill (SKILL.md) so it is clear, discoverable, and well-connected — frontmatter format, best practices for understandability, the typed [[type:name]] convention that links skills, agents, memories, and other config into a traversable graph, and how to bulletproof a discipline-enforcing skill against rationalization. Read before creating or editing any skill. Also use when you notice an important concept that no skill covers (a gap in the graph) and want to capture it as a new skill.
---

# Writing skills

Read this **before** creating or editing any skill. It covers how to write a good
one; global skills ship declaratively from the Nix config repo (see
[[skill:machine-layout]] for the repo and the edit → `git add` → rebuild flow), and
for how skills are discovered and how the `[[ ]]` graph is used at run time, see
[[skill:using-skills]].

## Anatomy

One folder per skill under the skills source directory, holding a single `SKILL.md`.
The file starts with `---`-delimited YAML frontmatter containing only:

- `name:` — kebab-case, exactly equal to the folder name.
- `description:` — a single prose paragraph (see below).

Everything after the closing `---` is the body, loaded only when the skill is
invoked.

## The description is the most important line

It is the *only* part of a skill that is always in context, and it is what makes
the model decide to open the skill. Write it to:

1. Say what the skill is, in one prose paragraph.
2. End with a concrete **"Use when…"** clause naming the situations, tasks, and
   keywords that should surface it.

**This deliberately contradicts `superpowers:writing-skills`.** That plugin skill
says a description must state *only* triggering conditions and never summarize the
workflow, and applies TDD to skill authoring. Here the opposite holds: the
description summarizes what the skill is *and* its workflow, because that is what
powers discovery and the `[[ ]]` graph — and skills here aren't test-driven by default (the one carve-out, for
discipline-enforcing skills, is below). When both surface, follow this skill (see the superpowers-precedence rule).

## Best practices for an understandable body

- **Lead with the key principle or rule** — don't bury it under setup.
- **Be concrete and actionable** — exact paths, commands, and filenames beat
  vague advice.
- **Keep it scannable** — short sections, headers, tables for mappings, bullets.
- **Give a brief "why"** so the rule generalizes to cases you didn't enumerate.
- **Call out carve-outs and what NOT to do** — failure modes prevent confusion.
- **One topic per skill** — split unrelated concerns into separate, linked skills
  rather than one mega-skill.
- **Assume no prior context** — spell out absolute paths; the reader may be a
  fresh session in an unrelated project.

## Discipline-enforcing skills: bulletproof them

Everything above suffices for a **reference** skill — one that states facts (where
config lives, how a tool works). Most skills here are that kind, and the techniques
in this section do **not** apply to them.

A **discipline-enforcing** skill is different: it says "you MUST always X before Y."
Its failure mode isn't confusion — it's defection. A future agent under pressure (a
deadline, sunk cost, an insistent user) *knows* the rule and rationalizes its way
around it, then writes a fluent justification for why it didn't apply this time.
Plain prose loses to a motivated defector. The techniques below — adapted from
`superpowers:writing-skills` — exist solely to defeat that, so apply them **only when
the skill enforces a rule.** On a reference skill they add noise with nothing to bind.

### Watch it fail first

Before writing the rule, hand the tempting scenario to a fresh subagent *without* the
skill, under the pressure that provokes the violation, and record the **exact words**
it uses to justify cutting the corner. If it complies even unaided, there's no failure
to fix — don't write the guidance. This is the one place testing earns its keep here;
the default that skills aren't test-driven still holds for reference skills.

### Rationalization table

Harvest those excuses verbatim into a two-column table — excuse | one-line rebuttal —
so a future agent meets its own loophole already closed by name:

| Excuse | Reality |
|--------|---------|
| "Too simple to test" | Simple code breaks. The test takes 30 seconds. |
| "I'll test after" | Tests passing immediately prove nothing. |
| "Tests-after achieve the same goal" | Tests-after ask "what does this do?"; tests-first ask "what *should* this do?" |

### Red-flags list

List the *thoughts* that signal an imminent violation, in the agent's own voice, so it
can self-catch the moment it starts rationalizing:

**Red flags — STOP:**
- "I already manually tested it"
- "It's about spirit, not ritual"
- "This is different because…"

### Bulletproof the rule

- **Close every loophole by name.** Don't stop at "delete it" — forbid the escape
  hatches too: don't keep it as "reference", don't adapt it while you work, don't even
  look at it. *Delete means delete.* A clever agent routes around any gap you leave.
- **Pre-empt letter-vs-spirit.** State once, early: *"Violating the letter of the rules
  is violating the spirit of the rules."* That cuts off the entire "I honored the
  spirit" class of excuse.

### Match the form to the failure

The *shape* of guidance that fixes one failure backfires on another. Classify the
baseline failure first, then pick the matching form:

| Baseline failure | Right form | Wrong form |
|---|---|---|
| Knows the rule, **skips it** under pressure | Prohibition + rationalization table + red flags | Soft "prefer…/consider…" |
| Complies, but **output is the wrong shape** (bloated, buried, restated) | Positive **recipe**: state what the output *is* — its parts, in order | Prohibition list ("don't restate", "never narrate") |
| **Omits a required element** it already produces | Structural **REQUIRED slot** in the template it fills | Prose reminders near the template |
| Behavior should **depend on a condition** | **Conditional** keyed to an observable predicate ("if the brief exists, reference it") | Unconditional rule + exemption clauses |

**Prohibitions backfire on shaping problems:** told "don't write a bloated prompt," an
agent under a competing incentive produces *more* of it — a recipe leaves nothing to
negotiate. Two corollaries: don't soften a winning recipe with a "unless it matters"
nuance clause (it reopens the negotiation), and don't trust exemption clauses to scope
— "this doesn't apply to code blocks" still suppresses code blocks; restructure so the
rule can't reach the exempt part instead.

### Micro-test the wording

Before committing a load-bearing phrase, run it 5+ times against fresh contexts beside
a **no-guidance control**, and read every hit by hand — template echoes and quoted
counter-examples masquerade as matches. Convergent output across reps means the wording
binds; five different readings means it's too loose, so tighten the *form* before
adding more words.

## Link your skill into the graph

Skills link to each other — and to agents, memories, and the other config kinds —
with `[[type:name]]` tokens; see [[skill:using-skills]] for the grammar, the full
type vocabulary, and why the graph is traversed at run time. When authoring:

- **Type every link.** A link is `[[type:name]]`: `type` says what the target is
  (`skill`, `agent`, `rule`, …) and `name` is its `name:` slug (= the folder, for a
  skill). Never a bare `[[name]]` — the type is mandatory.
- **Link inline** where one skill references another ("see [[skill:machine-layout]]"),
  and to agents too (`[[agent:code-reviewer]]`).
- **Link within reach.** Prefer targets that exist wherever this skill ships; a
  harness-specific target from a shared skill leaves a dangling edge elsewhere.
- **End with a `## Related skills` trailer:** a short section listing outgoing
  links, one per line — `- [[type:name]] — one-line reason to follow it`.
- **Link liberally and bidirectionally:** if A → B helps, B usually should point
  back to A, so the graph is navigable from any node — within a layer.
- **Stay within your layer.** Link global↔global and local↔local only; never a
  project-local skill → global target or vice versa, and never the local-only
  `spec`/`doc` types from a global skill. The context file (`CLAUDE.md` /
  `AGENTS.md`) bridges the layers (see [[skill:using-skills]]).
- **Add links to targets that don't exist yet.** A `[[skill:foo]]` pointing at a
  missing skill is a deliberate marker of where the graph should grow, not an
  error — and your cue to write that skill next (see [[skill:using-skills]]).

## Finish checklist

- `name:` equals the folder name.
- `description:` ends with a concrete "Use when…" clause.
- Body leads with the key rule and is scannable.
- If it enforces a discipline: baseline-tested, with a rationalization table, red
  flags, and the guidance form matched to the failure (see the section above).
- Related skills linked; forward / empty links added where useful.
- Doesn't duplicate another skill — link to it instead.
- `git add` the new file, then let the user rebuild (see [[skill:machine-layout]]).

## Related skills

- [[skill:using-skills]] — how skills are discovered and how the graph is traversed
- [[skill:machine-layout]] — the Nix machines these skills ship to, and the rebuild flow
