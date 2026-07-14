# AGENTS.md

Guidance for AI agents working in this repository.

## What this is

One Nix flake that fully defines Jake Neau's systems across **NixOS** (Linux)
and **nix-darwin** (macOS). The config is dogmatically declarative: system setup
lives in Nix, and program config goes through home-manager wherever possible so
it stays reproducible across machines.

It is organized around **three structured declarations** — `flake.programs`,
`flake.hosts`, `flake.users` — from which all wiring is generated, with every
user's home a standalone home-manager configuration; underneath, the dendritic
substrate on flake-parts auto-imports every `.nix` under `modules/` as a
feature module. **Read `.agents/skills/nix-config/SKILL.md` before adding or
changing anything** — it covers the declarations, the generated units, the
`flake.modules.<class>.<name>` aspects, and the rules for writing them. For how
anything here works at a high level — flows, architecture, tasks — start at
`docs/README.md` and consult the docs before the code (`reference/` for how the
machinery works, `how-to/` for tasks); code is for low-level detail only.

## Conventions

Core design principles (from the README):

- **Simple and elegant — above all.** Code here must always be simple and
  elegant. Prefer the smallest, clearest expression that does the job; reach for
  the existing aspect/factory/idiom before inventing a new one. Reject
  cleverness, redundancy, and incidental complexity. When two approaches work,
  choose the one that reads plainly. This takes precedence over every other
  convention below.
- **Nix only.** Use no package manager but Nix.
- **home-manager first.** Configure programs through home-manager — not
  imperatively, not at the system level — whenever home-manager can do it.
- **Prefer flakes.** Favor implementations that fully use flakes.
- **Formatting.** Format Nix with **`alejandra`**; match the existing 2-space
  indentation.
## Validating changes (dry-build; don't switch)

**After any modification to this repo, always confirm the configuration still
builds before considering the work done.** Run the relevant dry-build for the
host(s) you touched (and `nix flake check`); if a build fails, fix it or surface
the failure — never leave the repo in a non-building state.

Dry builds check evaluation and build without activating anything:

```sh
nix flake check
nix build .#nixosConfigurations.<host>.config.system.build.toplevel --no-link   # NixOS  (hosts: redwood, spruce)
nix build .#darwinConfigurations.<host>.system --no-link                        # macOS  (hosts: aspen, cedar)
nix build '.#homeConfigurations."<user>@<host>".activationPackage' --no-link    # homes (quote the dotted name)
nix run .#write-flake                    # regenerate flake.nix after changing inputs
```

Cross-platform note: a Mac has no Linux builder, so validate NixOS systems and
homes there by evaluating instead of building, e.g.
`nix eval --raw '.#homeConfigurations."<user>@<host>".activationPackage.drvPath'`.

**Always pass `--no-link`.** Without it (or via `nixos-rebuild build` /
`darwin-rebuild build`) the build tries to drop a `./result` symlink into this
root-owned repo and fails with a spurious `Permission denied` — _after_ the
build itself already succeeded.

`flake.nix` is **auto-generated** by `flake-file`; never hand-edit it. Declare
inputs via `flake-file.inputs` in the relevant feature, then regenerate.

Do **not** run `switch` rebuilds, `nix flake update`, or the `nr`/`nrr` shell
functions yourself — see below.

## Important cautions

- **Root-owned repos.** These configs live at root-owned paths (`/etc/nixos` on
  NixOS, `/etc/nix-darwin` on macOS), so editing normally needs `sudo` and plain
  edits fail on permissions. Where the `config` group is set up (see
  `modules/host-config/config-group`), its members own the tree and edit directly
  without `sudo` (owner stays `root`; only members get write). If edits still
  fail on permissions, surface it rather than silently retrying.
- **`nr` / `nrr` auto-commit AND push to GitHub.** These fish functions pull,
  update flake inputs, verify every environment in the flake (all systems and
  all homes), then `git add -A`, commit, and `git push` (sometimes
  `--force-with-lease`) to the public repo before rebuilding the system and
  reactivating the invoking user's home via `hr`. Never invoke them — or replicate
  their push behavior — unless the user explicitly asks. A rebuild here is
  system-wide and outward-facing.
- **Commit message format.** Generation commits are
  `<host> Generation <N>: <message>`, where `<host>` is the rebuilding machine
  and `<N>` is the upcoming generation number predicted from
  `/nix/var/nix/profiles/system` (the commit happens just before the rebuild).
  Running `nr` with no message _amends_ the last commit with an updated
  generation number. `nr` also accepts `-l`/`--long "<body>"` for an extended
  description; keep `<message>` at 50 characters or fewer and use the body only
  when the change genuinely needs one. Match this convention if asked to
  commit, but default to letting the user run the rebuild flow.
- **Secrets.** Managed with sops-nix + age. Never put plaintext secrets in
  `.nix` files; add them to `secrets/secrets.yaml` via sops. Never commit
  `secrets/keys.txt`; decryption needs that key present locally.
- **Don't `nix flake update` casually.** It bumps every input in `flake.lock`
  and belongs to the user's deliberate update flow.

## Related docs

- `docs/` — the Diátaxis tree (tutorials, how-to, reference, explanation): the
  source of truth for how this repo works at a high level, for humans and
  agents alike; start at `docs/README.md`.
- `README.md` — project overview, install steps, roadmap, usage shortcuts.
- `SKILLS.md` — how Claude Code skills are organized for this repo.
