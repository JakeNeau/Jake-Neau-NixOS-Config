---
name: writing-skills
description: How to author a Claude Code skill (SKILL.md) so it is clear, discoverable, and well-connected — frontmatter format, best practices for understandability, and the [[skill-name]] convention that links related skills into a traversable graph. Read before creating or editing any skill. Also use when you notice an important concept that no skill covers (a gap in the graph) and want to capture it as a new skill.
---

# Writing skills

Read this **before** creating or editing any skill. It covers how to write a good
one; for *where* skills live and the edit → `git add` → rebuild flow, see
[[claude-code-config]], and for how skills are discovered and how the `[[ ]]`
graph is used at run time, see [[using-skills]].

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

## Link your skill into the graph

Skills link to each other with `[[name]]` tokens — see [[using-skills]] for how
that graph works and why it is traversed at run time. When authoring:

- **Link inline** where one skill references another ("see [[machine-layout]]").
  `name` is the target skill's `name:` (= its folder).
- **End with a `## Related skills` trailer:** a short section listing outgoing
  links, one per line — `- [[name]] — one-line reason to follow it`.
- **Link liberally and bidirectionally:** if A → B helps, B usually should point
  back to A, so the graph is navigable from any node.
- **Add links to skills that don't exist yet.** A `[[name]]` pointing at a
  missing skill is a deliberate marker of where the graph should grow, not an
  error — and your cue to write that skill next (see [[using-skills]]).

## Finish checklist

- `name:` equals the folder name.
- `description:` ends with a concrete "Use when…" clause.
- Body leads with the key rule and is scannable.
- Related skills linked; forward / empty links added where useful.
- Doesn't duplicate another skill — link to it instead.
- `git add` the new file, then let the user rebuild (see [[claude-code-config]]).

## Related skills

- [[using-skills]] — how skills are discovered and how the graph is traversed
- [[claude-code-config]] — where skills live and how to ship them via the flake
- [[machine-layout]] — the Nix machine context these skills run on
