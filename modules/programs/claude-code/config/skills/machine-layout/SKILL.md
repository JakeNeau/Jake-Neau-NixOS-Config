---
name: machine-layout
description: Reference for how the user's machines are set up. Every machine is configured entirely and declaratively by Nix (NixOS on Linux, nix-darwin on macOS) from one flake-parts/dendritic flake plus home-manager, so system and user state belongs in the repo rather than imperative tweaks. The config repo lives at /etc/nixos on NixOS and /etc/nix-darwin on macOS. Use when you need to know where system or user configuration lives, how changes are applied, or to remember that a machine is Nix-managed before changing anything on it; for the in-depth flake guide see the nix-config skill.
---

# How this machine is laid out

**Every one of the user's machines is configured entirely and declaratively by
Nix** — NixOS on Linux, nix-darwin on macOS — from a single flake-parts /
dendritic flake plus home-manager. Nothing is set up imperatively: to change the
system or the user environment, edit the repo and rebuild, never hand-tweak the
running system.

## Where the config repo is

- **NixOS:** `/etc/nixos`
- **macOS:** `/etc/nix-darwin`

Same git repo on each. It is root-owned, with a dedicated `config` group granting
its members write access without sudo.

## Hosts

| Host | Platform |
| --- | --- |
| cedar | macOS (nix-darwin) |
| aspen | macOS (nix-darwin) |
| redwood | NixOS |
| spruce | NixOS |

## How changes are applied

`darwin-rebuild switch` (macOS) or `nixos-rebuild switch` (NixOS); home-manager
is folded into the system rebuild. The user has an `nr` helper that commits,
pushes, and then rebuilds.

**Never run `switch`, `nr` / `nrr`, or `nix flake update` yourself** — those
mutate the live system and push to GitHub. Stage changes and let the user run
the rebuild.

## Structure (brief)

Dendritic pattern: every `.nix` under `modules/` is auto-imported, and aspects
are placed at `flake.modules.<class>.<name>` (classes: `nixos`, `darwin`,
`homeManager`, `generic`). Roughly:

- `modules/hosts/<name>/` — per-host config
- `modules/users/<name>/` — per-user config (incl. home-manager)
- `modules/programs/<name>/` — reusable program modules

## Verify without switching

- `nix build .#darwinConfigurations.<host>.system --no-link` (always
  `--no-link` — the repo is root-owned, so a `./result` symlink fails).
- `nix eval --raw '.#darwinConfigurations.cedar.system.drvPath'`.
- Format Nix with **alejandra** (2-space indent).
- Git flakes only see tracked files → `git add` before you eval or build.

## Other facts

- **Secrets:** sops-nix + age. Never put plaintext secrets in `.nix` files.
- **`flake.nix` is auto-generated** — never hand-edit it; declare inputs via the
  flake-file feature, then `nix run .#write-flake`.

## Go deeper

When working inside the repo, the **nix-config** skill is the full guide to the
dendritic flake (aspects, design patterns, recipes), and `CLAUDE.md` holds the
complete conventions and cautions.

## Related skills

- [[claude-code-config]] — editing Claude Code's own config in this repo
- [[writing-skills]] — authoring skills that ship from this repo
