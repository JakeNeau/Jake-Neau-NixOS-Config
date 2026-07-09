---
name: writing-claude-md
description: How to write Claude Code memory (CLAUDE.md) — the global ~/.claude/CLAUDE.md (kept here as a minimal pointer) and project CLAUDE.md files — including the memory hierarchy, @path imports, and what makes memory effective. Use when editing global Claude context/memory or a project's CLAUDE.md, or deciding what belongs in memory vs a rule vs a skill.
---

# Writing CLAUDE.md memory

CLAUDE.md files are concatenated into Claude's context automatically. The global
one is the most expensive piece of config because it loads in **every** session.

## The global file in this repo

`config/CLAUDE.md` → `~/.claude/CLAUDE.md`. **Keep it a minimal pointer.** Detail
belongs in skills (on-demand) or rules (scoped) — not in the always-on global
file. See [[skill:claude-code-config]] for the edit → `git add` → rebuild flow.

## Memory hierarchy (load order, all concatenated — not overridden)

1. Managed policy (org-wide, enforced)
2. **User** — `~/.claude/CLAUDE.md` (this repo's global file)
3. **Project** — `./CLAUDE.md` or `./.claude/CLAUDE.md` (checked into a repo)
4. Local — `./CLAUDE.local.md` (gitignored, personal)

## `@path` imports

Pull in another file with `@path/to/file` (relative to the importing file; `~/`
supported). Imports resolve up to ~4 hops deep, and the first external import
triggers an approval prompt.

## Best practices

- **Keep it short** (aim well under ~200 lines); long memory dilutes adherence.
- **Be specific and structured** — headings + bullets, concrete instructions.
- **Choose the right home for content:**
  - global pointer / brief orientation → CLAUDE.md (here)
  - always-on or file-scoped instruction → rule ([[skill:writing-rules]])
  - large procedure loaded on demand → skill ([[skill:writing-skills]])

## Reference

Official docs (hierarchy, imports, memory):
https://code.claude.com/docs/en/memory

## Related skills

- [[skill:writing-rules]] — scoped / always-on instructions
- [[skill:writing-skills]] — on-demand procedures
- [[skill:claude-code-config]] — the declarative edit/ship workflow
- [[skill:starting-a-project]] — sharing a project's AGENTS.md/CLAUDE.md across every AI tool
