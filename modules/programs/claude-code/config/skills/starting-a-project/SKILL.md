---
name: starting-a-project
description: How to scaffold a new project so its agent instructions and skills are shared across every AI coding tool — Claude Code, Codex, Cursor, and the rest — instead of being locked to one. The pattern — keep a single source of truth at the repo root (an AGENTS.md for instructions and a .agents/skills/ directory for skills, following the cross-tool Agent Skills SKILL.md format), then bridge it to each tool's own vendor path (CLAUDE.md and .claude/skills/ for Claude Code) with symlinks so one edit updates every agent. Use when creating, scaffolding, or setting up a new project and you want its AGENTS.md instructions and .agents/skills skills to work across all agent tools; when deciding where a new project's agent instructions or SKILL.md files should live; or when wiring a project's .agents system so Claude Code picks it up.
---

# Starting a project

Keep one source of truth per project and symlink it out to each tool. Put
instructions in a root `AGENTS.md` and skills under `.agents/skills/`, then link
those to the vendor-specific paths each tool actually reads. One edit updates
every agent instead of N copies drifting apart.

## Why this layout

There is no cross-tool standard yet for *where* agent instructions or skills
live — only for their *format*. So each tool reads its own path, and the fix is
to pick one vendor-neutral home and bridge outward.

- **Instructions:** `AGENTS.md` at the repo root is the converging cross-tool
  filename — read natively by Codex, Cursor, and others. Claude Code is the
  exception: it reads its own `CLAUDE.md`, not `AGENTS.md`.
- **Skills:** the Agent Skills standard defines only the skill *folder* format (a
  directory with a `SKILL.md`), not a discovery location. `.agents/skills/` is the
  emerging vendor-neutral convention; Claude Code auto-loads only `.claude/skills/`.

Picking `.agents/` (not `.claude/`) as the home keeps the source neutral, so no
single tool owns it.

## Layout

```
my-project/
├── AGENTS.md                        # instructions — the source of truth
├── CLAUDE.md -> AGENTS.md           # or a one-line `@AGENTS.md` import (below)
├── .agents/
│   └── skills/
│       └── <skill>/SKILL.md         # skills — the source of truth
└── .claude/
    └── skills/
        └── <skill> -> ../../.agents/skills/<skill>
```

## Steps

1. **Write `AGENTS.md`** at the repo root — the project instructions (the same
   content you would otherwise put in `CLAUDE.md`): what the project is, its
   conventions, how to build and validate changes, and the cautions an agent
   must know — durable facts, not session-specific detail. When the project has
   a docs system, include the docs-navigation pointer: where the docs tree
   starts, and that docs come before code for high-level flows, per
   [[skill:documentation]].
2. **Write skills** under `.agents/skills/<name>/SKILL.md`, one folder per skill.
   Each file is YAML frontmatter (`name` + `description`) then a body — the
   cross-tool Agent Skills format. See [[skill:writing-skills]] for the anatomy
   (that skill targets *this repo's* declarative config, but the SKILL.md file
   format is identical).
3. **Bridge instructions to Claude Code** — either make `CLAUDE.md` a one-line
   `@AGENTS.md` import (safest across platforms, incl. Windows), or symlink it:
   `ln -s AGENTS.md CLAUDE.md`.
4. **Bridge skills to Claude Code** — symlink each skill into `.claude/skills/`,
   which Claude Code auto-loads and which follows symlinks:
   `ln -s ../../.agents/skills/<name> .claude/skills/<name>`. This gives full
   native behavior — the skill is invokable via the Skill tool with progressive
   disclosure, not just visible as text.
5. **Bridge to any other tools** you use with the same one-source-symlink-out
   pattern, per each tool's documented path (e.g. Codex, Cursor); check the
   tool's docs for where it looks.

## On this user's machines, `AGENTS.md` is already seen

Tools that read `AGENTS.md` natively (oh-my-pi, Codex, Cursor, …) discover the
root file themselves, and on this user's machines Claude Code gets it too: a
global `SessionStart` hook (`agents-md-context`) auto-injects a root `AGENTS.md`
and each `.agents/skills/` skill's frontmatter into every Claude Code session.
But that injection only supplies descriptions as context text; it does not
register skills as natively invokable. So the vendor-path symlinks are still
worth adding for full native behavior, and are required on any machine or tool
without such support. The injection and the symlinks are complementary, not
redundant.

## Don't

- **Don't keep separate per-tool copies** of the same instructions or skills —
  they drift. One source, symlinks out.
- **Don't make `.claude/` the source** and symlink the other way — `.claude/` is
  Claude-Code-specific; the vendor-neutral `.agents/` is the right home.

## Related skills

- [[skill:writing-skills]] — the SKILL.md anatomy (frontmatter + body) each skill file follows
- [[skill:using-skills]] — how skills are discovered and the `[[ ]]` graph
