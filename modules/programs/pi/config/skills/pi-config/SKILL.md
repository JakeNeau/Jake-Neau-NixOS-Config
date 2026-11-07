---
name: pi-config
description: >
  How to change Pi's own configuration: the system prompt addendum, the global
  AGENTS.md, prompts, skills, extensions, settings, and the typed-link
  registry. All of it is generated from modules/programs/pi/ in the user's Nix
  configuration. Use before creating, editing, or removing any of those,
  including every new skill.
---

# Editing Pi's configuration

Pi's configuration is part of the Nix configuration. Follow
[[skill:system-config]] for the repository rules and [[skill:nix-config]] for
where the repository is and how the user applies a change. Never edit
`~/.pi/` directly. Home Manager regenerates it on every rebuild.

## Where it lives

Everything is under `modules/programs/pi/`:

- `pi.nix`: the `flake.programs.pi` declaration, the package, settings, and the
  wiring of every file below into `~/.pi/agent/`.
- `config/APPEND_SYSTEM.md`: the system prompt addendum.
- `config/AGENTS.md`: the global context file.
- `config/prompts/<name>.md`: prompt templates, each a `/<name>` command.
- `config/skills/<name>/SKILL.md`: the skills.
- `config/agents/<name>.md`: subagent profiles, per
  [[skill:writing-pi-agents]].
- `extensions/<name>/`: TypeScript extensions with their tests.
- `writing/`: the `pi-writing-lint` command.

`docs/reference/pi.md` describes the whole module and names each skill. Update
it in the same change.

## Skills

Every skill under `config/skills/` is global. Home Manager links each
directory into `~/.pi/agent/skills/` and the typed-link registry indexes it as
`global:skill:<name>`. A new skill for Pi goes there unless the user states
otherwise when creating it. A skill that belongs to one project stays in that
project's `.agents/skills/` and is never made global.

A global skill's name and description enter every session's system prompt, so
keep the description to the trigger and the scope. The body loads only when Pi
calls `follow_link global:skill:<name>` or reads it through a `[[skill:<name>]]`
link.

To add or remove a skill:

1. Create or delete `config/skills/<name>/SKILL.md` with `name` and
   `description` frontmatter.
2. Add or remove its id in `EXPECTED_IDS` in
   `extensions/typed-links/tests/writing-resources.test.mjs`. The registry
   build runs that test and fails on any difference.
3. Add or remove every `[[skill:<name>]]` link that points at it. The test
   rejects unresolved global links.
4. Describe it in `docs/reference/pi.md`.

## Prompts and context

A prompt template is a Markdown file with `description` and `argument-hint`
frontmatter. `pi.nix` links every file under `config/prompts/` automatically.
`AGENTS.md` and `APPEND_SYSTEM.md` are read verbatim, so edit the file and
rebuild.

## Extensions

Follow [[skill:writing-pi-extensions]]. An extension's tests run inside the Nix
build, so a failing test fails the home.

## Validate

Run the extension tests through Nix, then:

```sh
nix flake check
nix build '.#homeConfigurations."<user>@<host>".activationPackage' --no-link
```

Never run `hr`, `nr`, `nrr`, or a `switch` command.

## Related skills

- [[skill:system-config]]: the repository rules and edit procedures
- [[skill:nix-config]]: where the repository is and how a change is applied
- [[skill:writing-pi-extensions]]: creating and changing extensions
- [[skill:writing-pi-agents]]: creating and changing subagent profiles
