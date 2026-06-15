---
name: writing-rules
description: How to author a Claude Code rule in this repo — a markdown file under config/rules/ that is auto-loaded as memory, optionally scoped to file globs via paths: frontmatter. Covers when to use a rule vs CLAUDE.md vs a skill, and keeping always-on context small. Use when adding a persistent instruction or coding convention Claude should always (or conditionally) follow.
---

# Writing rules

A rule is a markdown file that is **auto-loaded as memory** — Claude follows it
without being asked. Author one as a file; see [[claude-code-config]] for the
edit → `git add` → rebuild flow.

## Where it goes

`config/rules/<name>.md` → `~/.claude/rules/<name>.md`. These are **global user
rules**, so they load in **every** session on the machine — be mindful of the
always-on context cost.

## Scope a rule to files with `paths:`

Without frontmatter, a rule loads at session start (like CLAUDE.md). With a
`paths:` glob, it loads only when matching files are in context — use this to keep
heavy or domain-specific rules off the always-on budget:

```markdown
---
paths:
  - "**/*.test.ts"
  - "src/api/**"
---

Always co-locate tests and mock the network layer.
```

## Best practices

- **Be specific and imperative:** "Use 2-space indentation" beats "format code
  properly."
- **Structure** with short headings and bullets, not dense paragraphs.
- **Scope with `paths:`** anything that isn't relevant to every session.
- Keep each rule small and single-topic; watch for rules that conflict with
  CLAUDE.md.

## Rule vs CLAUDE.md vs skill

- Small, always-on instruction / convention → **rule** (this skill).
- Brief global orientation or a pointer → **CLAUDE.md** ([[writing-claude-md]]).
- Large, on-demand procedure loaded only when relevant → **skill**
  ([[writing-skills]]).

## Reference

Official docs (memory + rules behavior):
https://code.claude.com/docs/en/memory

## Related skills

- [[writing-claude-md]] — the global context file and memory hierarchy
- [[writing-skills]] — for on-demand procedures instead of always-on rules
- [[claude-code-config]] — the declarative edit/ship workflow
