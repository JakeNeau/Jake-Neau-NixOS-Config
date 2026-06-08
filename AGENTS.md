# AGENTS.md

Guidance for AI agents working in this repository.

## What this is

A single Nix flake that fully defines Jake Neau's systems across platforms —
NixOS (Linux) and nix-darwin (macOS). Configuration is dogmatically declarative:
system setup lives in Nix, and program configuration is pushed through
home-manager wherever possible so it stays reproducible across machines.

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
nixos-rebuild build --flake .#<host>     # NixOS
darwin-rebuild build --flake .#<host>    # macOS
```

Do **not** run `switch` rebuilds, `nix flake update`, or the `nr`/`nrr` shell
functions on your own — see below.

## Important cautions for agents

- **Root-owned repos.** These configs live at root-owned paths (`/etc/nixos` on
  NixOS, `/etc/nix-darwin` on macOS). Editing files therefore requires `sudo`;
  plain file edits will fail on permissions. Surface this rather than silently
  retrying.
- **`nr` / `nrr` auto-commit AND push to GitHub.** The fish functions rebuild the
  system and then `git add -A`, commit, and `git push` (sometimes
  `--force-with-lease`) to the public repo. Never invoke them, or replicate their
  push behavior, unless the user explicitly asks. A rebuild here is system-wide
  and outward-facing.
- **Commit message format.** Generation commits use
  `Generation <N>: <message>`, where `<N>` is the system generation number from
  `/nix/var/nix/profiles/system`. Running `nr` with no message *amends* the last
  commit with an updated generation number. Match this convention if asked to
  commit, but default to letting the user run the rebuild flow.
- **Secrets.** Secrets are managed with sops-nix + age. Never put plaintext
  secrets in `.nix` files; add them to `secrets/secrets.yaml` via sops. Never
  commit `secrets/keys.txt`. Decryption requires that key present locally.
- **Don't `nix flake update` casually.** It bumps all inputs in `flake.lock` and
  is normally done as part of the user's deliberate update flow.

## Related docs

- `README.md` — project overview, install steps, roadmap, usage shortcuts.
- `SKILLS.md` — how Claude Code skills are organized for this repo.
