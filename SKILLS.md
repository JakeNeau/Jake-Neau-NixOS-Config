# Skills

How Claude Code skills are organized for this repo, how to sync the global ones
across machines via nix, and an index of the skills that live in this project.

## Where skills live

Claude Code loads skills from two locations, and both are available while working
in this project:

- **Global (all projects):** `~/.claude/skills/<name>/SKILL.md`
- **Project (this repo only):** `.claude/skills/<name>/SKILL.md`

Each skill is a directory containing a `SKILL.md` with `name` / `description`
frontmatter, plus any supporting files it needs. Use global for tools you want
everywhere; commit project skills into this repo so they travel with it.

(A third option, **plugins**, can bundle and distribute skills via a marketplace —
useful for sharing with others, heavier-weight than personal skills.)

## Syncing global skills across machines (nix)

This config is managed with nix-darwin, so the cleanest way to keep
`~/.claude/skills/` reproducible across machines is to manage it declaratively.

Keep the skills in a directory in this repo (e.g. `claude/skills/`) and wire them
in with home-manager:

```nix
home.file.".claude/skills" = {
  source = ./claude/skills;   # directory tracked in this repo
  recursive = true;
};
```

After `darwin-rebuild switch`, the skills are reproduced on every machine.

Caveat: home-manager links files read-only into the nix store, so edit the skill
in this repo and rebuild rather than editing under `~/.claude` directly. If you
want live edits, use a plain dotfiles symlink or `mkOutOfStoreSymlink` instead.

## Project skills

Skills specific to this nix-darwin repo live under `.claude/skills/`:

- **nix-config** (`.claude/skills/nix-config/SKILL.md`) — how this configuration
  is structured and how to work in it: the dendritic / flake-parts layout shared
  across NixOS and macOS, features/aspects/module classes, the flake wiring, and
  recipes and conventions for adding or editing configuration. Bundles
  `aspects.md`, a reference for the eight aspect design patterns.
