---
name: using-skills
description: How Claude Code skills work and how to get the most from them — what a skill is, how discovery works (the always-in-context description vs the on-demand body), why to reach for skills proactively, the [[skill-name]] graph you traverse at use time, and when to grow the graph by writing a new skill. Use when deciding whether to consult a skill, when following links between skills/memories, when you spot a concept no skill covers, or to understand the skill system itself; to author a skill, see [[writing-skills]].
---

# Using skills

Skills are on-demand guidance you can pull into context. Use them proactively:
when a task matches a skill, open it and follow it before acting.

## How a skill loads

- A skill's **description** is always in context — it is the trigger that tells
  you the skill exists and when it applies.
- The **body** loads only when you invoke the skill. Consulting a skill is cheap
  by default and detailed on demand, so reach for one whenever it is relevant
  rather than guessing from the description alone.

## The `[[ ]]` graph — traverse it aggressively

Skills and memories form a graph linked with `[[name]]` tokens, where `name` is
the target's `name:` slug. This is the same convention the memory system uses, so
skills and memories link identically. **Lean on this graph as your primary way to
find related guidance.**

- **Chase links eagerly, at use time.** When a skill or memory you are reading
  links to `[[another]]`, follow it whenever it could be relevant — and keep
  going, several hops deep, rather than stopping at the first skill. Treat the
  links as a map to traverse, not a footnote. A few extra reads are cheap next to
  missing guidance that was one hop away.
- **Expect dangling links.** A `[[name]]` may point at a skill that does not
  exist yet; that is a deliberate marker of where the graph should grow, not an
  error.

## Grow the graph — write skills aggressively

When you hit a concept no skill covers — or follow a `[[ ]]` link to a skill that
does not exist yet — that is your cue to **create the skill**. Be eager about it:
capturing knowledge as a linked skill is almost always worth it. Do not hold back
for fear of the tree getting large; over-growth is pruned separately, so the
right default is to add, link, and move on. For how to author one well, see
[[writing-skills]].

## Related skills

- [[writing-skills]] — how to author a skill (anatomy, frontmatter, linking)
- [[claude-code-config]] — where skills live and how they ship via the Nix flake
