# Skills

How Claude Code skills are organized for this repo, how to sync the global ones
across machines via nix, and an index of the skills that live in this project.

## Where skills live

Claude Code loads skills from two locations, and both are available while working
in this project:

- **Global (all projects):** `~/.claude/skills/<name>/SKILL.md`
- **Project (this repo only):** `.agents/skills/<name>/SKILL.md`

Each skill is a directory containing a `SKILL.md` with `name` / `description`
frontmatter, plus any supporting files it needs. Use global for tools you want
everywhere; commit project skills into this repo so they travel with it.

(A third option, **plugins**, can bundle and distribute skills via a marketplace —
useful for sharing with others, heavier-weight than personal skills.)

## Syncing global skills across machines (nix)

Global skills are managed declaratively by the claude-code feature: author them
under `modules/programs/claude-code/config/skills/` and they land in
`~/.claude/skills/` on every machine — see `modules/programs/claude-code/` and
[docs/explanation/claude-code-config.md](docs/explanation/claude-code-config.md).

## Project skills

Skills specific to this nix-darwin repo live under `.agents/skills/`. Claude Code
does not natively read `.agents/skills/`, so on these machines the global
`agents-md-context` SessionStart hook surfaces them into each session.

- **nix-config** (`.agents/skills/nix-config/SKILL.md`) — how this configuration
  is structured and how to work in it: the three structured declarations
  (`flake.programs` / `flake.hosts` / `flake.users`) from which the wiring is
  generated, standalone home-manager homes, the dendritic substrate beneath,
  and how to perform every kind of edit to the repo. Bundles `aspects.md`, a
  reference for the aspect design patterns (Declaration plus the seven
  dendritic ones).
- **nvf** (`.agents/skills/nvf/SKILL.md`) — how to configure Neovim with
  [nvf](https://github.com/NotAShelf/nvf) using the standalone flake method
  (`nvf.lib.neovimConfiguration`), which builds Neovim as a self-contained,
  portable package exposed as a flake output rather than a NixOS/home-manager
  module. Covers the builder API, the `vim` option namespace, wiring the built
  editor into a host, and migrating off the old `programs.nvf` module.
- **repo-permissions** (`.agents/skills/repo-permissions/SKILL.md`) — how write
  access to this root-owned repo works: the `config` group owns `/etc/nixos` so
  members edit without sudo, how to check it is set up on the current machine,
  and the one-time setup steps. Surfaces the gap to the user when the setup is
  missing (e.g. on a new machine or fresh clone).
- **default-apps** (`.agents/skills/default-apps/SKILL.md`) — how to set the
  default handler for a file type or URL scheme across NixOS and macOS: Linux's
  declarative `xdg.mimeApps`, and macOS's guarded `duti` activation plus the
  `mac-app-util` trampolines that let the guard stick. Covers the anti-hijacking
  modal trap and how to find the bundle ids / UTIs you need.
- **todo-tracking** (`.agents/skills/todo-tracking/SKILL.md`) — how this repo
  tracks TODOs: every outstanding work item goes in the single `TODO.md`
  checklist at the repo root, in the flat `- [ ]` format described there.
