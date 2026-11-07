---
name: writing-pi-agents
description: >
  How to author a Pi subagent profile declaratively: a Markdown file with YAML
  frontmatter under modules/programs/pi/config/agents/, linked into
  ~/.pi/agent/agents/ by Home Manager. Covers the frontmatter fields, context
  and tool restriction, council advisor profiles, and overriding a bundled
  agent. Use before creating, editing, or removing a subagent profile.
---

# Writing Pi agent profiles

A profile defines one specialist that the `subagent` tool runs as a child
session. It is a Markdown file: YAML frontmatter on top, the child's system
prompt below. Profiles ship from `modules/programs/pi/config/agents/<name>.md`
in the Nix configuration, per [[skill:pi-config]]. Never write to
`~/.pi/agent/agents/` directly.

## Read the contract first

Resolve the installed pi-subagents documentation with:

```bash
root=$(grep -o '/nix/store/[^"]*/pi-subagents' ~/.pi/agent/extensions/subagent/index.ts)
agents_doc="$root/docs/agents.md"
```

Read its `Frontmatter reference` and `Prompt assembly` sections before writing
a field. The bundled profiles beside it under `agents/` are working examples.
Copy the shape of the closest one.

## Minimum profile

```yaml
---
name: scout
description: Fast codebase recon
tools: read, grep, find, ls
---

Your system prompt goes here.
```

A user profile with the same `name` as a bundled agent replaces it.

## Fields that matter most

- `tools`: a strict allowlist. A child never inherits the parent's extension
  tools. Keep a reviewer or advisor read-only.
- `systemPromptMode`: `replace` by default. Use `append` only when the child
  must keep Pi's base prompt.
- `inheritProjectContext`, `inheritGlobalContext`, `inheritSkills`: all narrow
  by default. Grant only what the role needs, because every inherited block
  costs the child context.
- `defaultContext`: `fresh` or `fork`. A fork sends the parent's whole prompt.
- `acceptanceRole`: `read-only` or `writer`, for acceptance inference.
- `thinking` and `model`: set only when the role needs a specific level.
- `advertise`: `true` puts the name and description into the parent prompt.
  Leave it off unless the parent must discover the agent without a `list`.

## Council advisors

Council mode needs two to four profiles whose names start with `council-`.
Each holds its persistent stance in the body, stays read-only, and disables
inherited skills unless the stance needs them. The council skill fills a short
roster with `oracle` and `reviewer`.

## Validate

Keep the prompt body to the role, its rules, and the shape of its final
response. Then dry-build the home per [[skill:pi-config]] and run
`/subagents` in a new session to confirm the profile lists.

## Related skills

- [[skill:pi-config]]: where Pi's configuration lives and how it is wired
- [[skill:system-config]]: the repository rules and edit procedures
- [[skill:nix-config]]: where the repository is and how a change is applied
