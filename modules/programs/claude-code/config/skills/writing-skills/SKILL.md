---
name: writing-skills
description: How to author a Claude Code skill (SKILL.md) so it is clear, discoverable, and well-connected — frontmatter format, best practices for understandability, and the [[skill-name]] convention that links related skills into a traversable graph. Read before creating or editing any skill. Also use when you notice an important concept that no skill covers (a gap in the graph) and want to capture it as a new skill.
---

# Writing skills

Read this **before** creating or editing any skill. It covers how to write a good
one; for *where* skills live and the edit → `git add` → rebuild flow, see
[[claude-code-config]].

## Anatomy

One folder per skill under `config/skills/<name>/`, holding a single `SKILL.md`.
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

## Link skills into a graph with `[[ ]]`

Skills form a graph the model can traverse. This uses the same convention as the
memory system, so skills and memories link identically.

- **Link token:** `[[skill-name]]`, where `skill-name` is the target skill's
  `name:` (= its folder). Use it inline ("see [[machine-layout]]").
- **`## Related skills` trailer:** end every skill with a short section listing
  its outgoing links, one per line: `- [[name]] — one-line reason to follow it`.
- **Link liberally and bidirectionally:** if A → B helps, B usually should point
  back to A, so the graph is navigable from any node.

## Create empty links to future skills — liberally

Don't link only skills that exist. **Proactively add `[[ ]]` links to skills that
*would be useful to have* but don't exist yet**, and be generous about it. A
`[[name]]` pointing at a missing skill is not an error — it is a free, meaningful
marker that flags where the graph should grow. These dangling links cost nothing,
sketch the intended shape of the knowledge graph, and become a ready-made backlog
of skills worth writing. When you hit one (or notice a concept no skill covers),
that is your cue to create the skill there and link it in.

## Finish checklist

- `name:` equals the folder name.
- `description:` ends with a concrete "Use when…" clause.
- Body leads with the key rule and is scannable.
- Related skills linked; forward / empty links added where useful.
- Doesn't duplicate another skill — link to it instead.
- `git add` the new file, then let the user rebuild (see [[claude-code-config]]).

## Related skills

- [[claude-code-config]] — where skills live and how to ship them via the flake
- [[machine-layout]] — the Nix machine context these skills run on
