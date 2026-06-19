---
name: using-skills
description: How Claude Code skills work and how to get the most from them — what a skill is, how discovery works (the always-in-context description vs the on-demand body), why to reach for skills proactively, the [[ ]] graph of skills, agents, and memories you traverse at use time, and when to grow the graph by writing a new skill. Use when deciding whether to consult a skill, when following links between skills, agents, and memories, when you spot a concept no skill covers, or to understand the skill system itself; to author a skill, see [[skill:writing-skills]].
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

## The `[[type:name]]` graph — traverse it aggressively

Skills, agents, memories, and the other config kinds form a graph linked with
`[[type:name]]` tokens: `type` says *what the target is* and `name` is its `name:`
slug (e.g. `[[skill:writing-skills]]`, `[[agent:code-reviewer]]`). The type is
**mandatory** — it tells you what to *do* with the link right at the link site:
read a skill, dispatch an agent, recall a memory. The memory system uses the same
convention, so every node links identically. **Lean on this graph as your primary
way to find related guidance.**

`type` is one value from a closed vocabulary, split by which layer it may appear in:

| Type | Where it may appear |
|---|---|
| `skill`, `agent`, `memory`, `rule`, `command`, `hook`, `mcp` | either layer |
| `spec`, `doc` | project-local only — these have no global instances |

- **Always type the link.** Never write a bare `[[name]]`; the type is what makes
  the edge unambiguous and checkable.
- **Chase links eagerly, at use time.** When something you are reading links to
  `[[skill:another]]`, follow it whenever it could be relevant — several hops deep,
  not just the first. The links are a map to traverse, not a footnote: a few extra
  reads are cheap next to guidance that was one hop away.
- **Dangling links still carry a type.** `[[skill:foo]]` may point at a skill that
  does not exist yet — a deliberate marker of where the graph should grow, declaring
  intent (`skill:` vs `agent:`) before the target exists. Not an error.

## Two layers — keep links within one

The graph splits into two layers, and `[[type:name]]` edges must stay inside one:

- **Global** — `config/skills/` + `config/agents/` (and the global rules, commands,
  hooks, MCP servers), shipped to every machine by the Nix flake. Available in any repo.
- **Project-local** — a repo's own `.claude/skills/` + `.claude/agents/` (plus its
  specs and docs); exists only in that repo.

A global skill that links a project-local one breaks in every *other* repo (the
target isn't there); a local skill that links outward couples the repo to
machine-wide config. So link **within a layer** only — each layer spans all its own
config kinds, and neither links across. The `spec` and `doc` types have no global
instances, so a `[[spec:…]]` or `[[doc:…]]` edge is inherently local-only — emitting
one from a global skill is wrong by construction. `CLAUDE.md` (global and per-project)
is the bridge between layers, not cross-layer `[[type:name]]` edges.

## Grow the graph — write skills aggressively

When you hit a concept no skill covers — or follow a `[[ ]]` link to a skill that
does not exist yet — that is your cue to **create the skill**. Be eager about it:
capturing knowledge as a linked skill is almost always worth it. Do not hold back
for fear of the tree getting large; over-growth is pruned separately, so the
right default is to add, link, and move on. For how to author one well, see
[[skill:writing-skills]].

## Related skills

- [[skill:writing-skills]] — how to author a skill (anatomy, frontmatter, linking)
- [[skill:claude-code-config]] — where skills live and how they ship via the Nix flake
