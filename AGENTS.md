# AGENTS.md

Guidance for AI agents working in this repository.

## What this is

A single Nix flake that fully defines Jake Neau's systems across platforms —
NixOS (Linux) and nix-darwin (macOS). Configuration is dogmatically declarative:
system setup lives in Nix, and program configuration is pushed through
home-manager wherever possible so it stays reproducible across machines.

The flake is organized with the **dendritic pattern** on top of flake-parts:
every `.nix` under `modules/` is a feature module, auto-imported by
`import-tree`, and hosts/users are themselves features composed of smaller ones.
Read `.claude/skills/nix-config/SKILL.md` before adding or changing anything —
it documents the module classes, the `flake.modules.<class>.<name>` aspects, the
host/user factories, and the rules for writing them.

## Conventions

Follow the project's core design principles (from the README):

- **Nix only.** Avoid every package manager except the Nix package manager.
- **home-manager first.** Any program configuration achievable through
  home-manager should be done in home-manager, not imperatively or at the system
  level.
- **Prefer flakes.** Favor implementations that fully utilize flakes.
- **Formatting:** format Nix with **`alejandra`** (the formatter this repo uses).
  Match existing 2-space indentation.

## Validating changes (do this; don't switch)

Prefer dry builds — they check evaluation and build without activating anything:

```sh
nix flake check
nix build .#nixosConfigurations.<host>.config.system.build.toplevel --no-link   # NixOS  (hosts: nixos-desktop, nixos-laptop)
nix build .#darwinConfigurations.<host>.system --no-link                        # macOS  (hosts: macos-laptop, jake-neau-work-laptop)
nix run .#write-flake                    # regenerate flake.nix after changing inputs
```

Always pass `--no-link`: without it (or via `nixos-rebuild build` /
`darwin-rebuild build`) the build tries to drop a `./result` symlink into this
root-owned repo and fails with a spurious `Permission denied` after the build
itself has already succeeded.

`flake.nix` is **auto-generated** by `flake-file` and must not be hand-edited;
declare inputs via `flake-file.inputs` in the relevant feature and regenerate.

Do **not** run `switch` rebuilds, `nix flake update`, or the `nr`/`nrr` shell
functions on your own — see below.

## Important cautions for agents

- **Root-owned repos.** These configs live at root-owned paths (`/etc/nixos` on
  NixOS, `/etc/nix-darwin` on macOS), so by default editing files requires
  `sudo` and plain file edits fail on permissions. On NixOS hosts where the
  `config` group has been set up (see `modules/system/config-group`), members of
  that group own the tree and can edit `/etc/nixos` directly without `sudo`
  (owner stays `root`; only `config` members get write). If edits still fail on
  permissions, surface it rather than silently retrying.
- **`nr` / `nrr` auto-commit AND push to GitHub.** The fish functions pull,
  update the flake inputs, verify that every environment in the flake builds,
  then `git add -A`, commit, and `git push` (sometimes `--force-with-lease`) to
  the public repo before rebuilding the system. Never invoke them, or replicate
  their push behavior, unless the user explicitly asks. A rebuild here is
  system-wide and outward-facing.
- **Commit message format.** Generation commits use
  `<host> Generation <N>: <message>`, where `<host>` is the machine running the
  rebuild and `<N>` is the upcoming system generation number predicted from
  `/nix/var/nix/profiles/system` (the commit happens just before the rebuild).
  Running `nr` with no message *amends* the last commit with an updated
  generation number. Match this convention if asked to commit,
  but default to letting the user run the rebuild flow.
- **Secrets.** Secrets are managed with sops-nix + age. Never put plaintext
  secrets in `.nix` files; add them to `secrets/secrets.yaml` via sops. Never
  commit `secrets/keys.txt`. Decryption requires that key present locally.
- **Don't `nix flake update` casually.** It bumps all inputs in `flake.lock` and
  is normally done as part of the user's deliberate update flow.

## Related docs

- `README.md` — project overview, install steps, roadmap, usage shortcuts.
- `SKILLS.md` — how Claude Code skills are organized for this repo.
