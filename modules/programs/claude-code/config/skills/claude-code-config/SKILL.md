---
name: claude-code-config
description: How to add or change Claude Code's own configuration on this machine — skills, agents, slash commands, rules, hooks, MCP servers, and the global CLAUDE.md. All of it is generated declaratively by Nix from a flake; the live files under ~/.claude are read-only symlinks and must never be edited directly. Use when asked to create, edit, or remove a skill/agent/command/rule/hook/MCP server for Claude (globally or "for me"), or to change global Claude Code config, so the change lands in the flake and is shared across all the user's machines.
---

# Editing Claude Code's own config

**This config is declarative. Never edit `~/.claude` directly.** The files under
`~/.claude/{agents,commands,rules,hooks,skills}/` and `~/.claude/CLAUDE.md` are
read-only Nix-store symlinks generated from the flake — editing them fails, and
any stray file you drop in is erased on the next rebuild. Always edit the source
in the repo instead.

## Where the source lives

`modules/programs/claude-code/config/` in the Nix config repo
(`/etc/nix-darwin` on macOS, `/etc/nixos` on NixOS — see [[machine-layout]]).

## Two ways to edit config

**1. File-based** — create or edit a file under `config/<subdir>/`:

| Edit this source file | Becomes |
| --- | --- |
| `config/agents/<name>.md` | `~/.claude/agents/<name>.md` |
| `config/commands/<name>.md` | `~/.claude/commands/<name>.md` |
| `config/rules/<name>.md` | `~/.claude/rules/<name>.md` |
| `config/hooks/<name>` | `~/.claude/hooks/<name>` (verbatim, executable) |
| `config/skills/<name>/SKILL.md` | `~/.claude/skills/<name>/SKILL.md` |
| `config/CLAUDE.md` | `~/.claude/CLAUDE.md` (global context) |

**2. Nix-attrset** — edit Nix code, *not* a file under `config/`:

- **LSP servers** → the `lspServers` attrset in `claude-code.nix`
  (see [[configuring-lsp-servers]]).
- **MCP servers** → `programs.mcp.servers`, pulled in via `enableMcpIntegration`
  (see [[configuring-mcp-servers]]).

**Hooks caveat:** a hook file alone does **not** fire — the module ships the
script, but you must register it in `settings.json` separately. See
[[writing-hooks]].

## Per-config-type guides — read the matching one before editing

Each config type has its own best-practices skill. Read the relevant one first:

- [[writing-agents]] — subagents (`config/agents/`)
- [[writing-commands]] — slash commands (`config/commands/`)
- [[writing-rules]] — auto-loaded rules / memory (`config/rules/`)
- [[writing-hooks]] — event hooks (`config/hooks/` + settings.json registration)
- [[writing-skills]] — skills (one `SKILL.md` per skill, no supporting files)
- [[writing-claude-md]] — the global `CLAUDE.md` and memory
- [[configuring-lsp-servers]] — language servers (Nix attrset)
- [[configuring-mcp-servers]] — MCP servers (Nix attrset)

Not yet wired here (upstream supports them — future skills):
[[configuring-output-styles]], [[configuring-plugins]].

## Not managed by Nix — edit live, no rebuild

`~/.claude/settings.json` (effort level, theme, hook registrations),
`~/.claude/keybindings.json`, and runtime state (history, sessions, caches) stay
mutable on purpose. Change these in place; do not move them into the flake. For
settings.json specifically, use the built-in `update-config` skill.

## Workflow

1. Edit or create the matching source file under `config/`.
2. `git add` it — the flake only sees git-tracked files, so an untracked file is
   invisible to the build.
3. Rebuild to apply. Changes are inert until then.

Do **not** run `switch` / `nr` yourself (see [[machine-layout]]); stage the
change and let the user rebuild.

Routing every change through the flake is what keeps this config reproducible and
identical across all the user's machines.

## Related skills

- [[writing-skills]] — read before authoring or editing a skill
- [[machine-layout]] — where the Nix config lives and how a rebuild is applied
