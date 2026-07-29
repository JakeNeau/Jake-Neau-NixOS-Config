---
name: nix-config
description: How this Nix configuration is structured and how to work in it. One flake-parts flake defines NixOS and macOS (nix-darwin) machines through three structured declarations — flake.programs, flake.hosts, flake.users — from which all wiring is generated, with every user's home a standalone home-manager configuration. Use when adding, editing, or understanding anything here — programs, hosts, users, aspects, roles, services, secrets, flake inputs, validation, or the flake wiring.
---

# How this Nix configuration works

This repository is **one Nix flake** defining Jake's machines across **NixOS**
(Linux) and **nix-darwin** (macOS). Its primary organizing idea is **three
structured declarations** from which all wiring is generated:

- **`flake.programs.<name>`** — how a program installs and its shared config.
- **`flake.hosts.<name>`** — what a machine is: class, users, global programs.
- **`flake.users.<name>`** — a user's own program requests, per host if needed.

Every user's home is a **standalone home-manager** output,
`homeConfigurations."<user>@<host>"`, rebuilt by the user with `hr` — there is
no home-manager system module. Beneath the declarations sits the dendritic
substrate (auto-imported feature modules); hand-written aspects remain
first-class as the escape hatch for what declarations don't cover, but they
are never the default recipe.

The full documentation is the Diátaxis tree under `docs/` — this skill states
each action briefly and links to the page that carries the depth.

## The three declarations

Field-by-field schema:
[declaration schema reference](../../../docs/reference/declaration-schema.md).
Rationale:
[the framework's why](../../../docs/explanation/declaration-framework.md).

- **`flake.programs.<name>`** (in `modules/programs/<name>/`) declares install
  ways per platform (`install.linux`: `home`/`system`; `install.macos`:
  `home`/`cask`) plus a shared home-manager `config` module. The generator
  emits importable `flake.modules` units — `homeManager.<name>`,
  `homeManager.<name>-config`, `nixos.<name>`/`darwin.<name>`, tombstones for
  unsupported imports — per the
  [generated-units reference](../../../docs/reference/generated-units.md).
- **`flake.hosts.<name>`** (in `modules/hosts/<host>/configuration.nix`)
  declares `class`, `system`, `users`, `globalPrograms`, `installOverrides`,
  and `baselines`. The generator routes each global program's halves by its
  resolved install way, generates the `<host>-host-config` and
  `<host>-baseline` aspects, and stamps the flake outputs — per the
  [generated host artifacts reference](../../../docs/reference/generated-host-artifacts.md).
- **`flake.users.<name>`** (in `modules/users/<user>/`) declares `programs`
  (all the user's machines) and `hosts.<h>.programs` (one machine) —
  per-user-only channels that resolve to home-manager units, never system
  installs.

**The one-channel home model:** `homeConfigurations."<user>@<host>"` = the
user's own aspect (unwrapped, the overriding layer) + the host's baseline +
the user's resolved declaration units, with everything shared lowered to
priority 900 by the boundary wrapper — so a user's plain assignment (100)
overrides any shared default. Lists are exempt: shared lists merge with the
user's own at plain priority (replace one with `mkForce`), because priority
filtering would delete, not demote, them. Nothing else may deliver config to
a home:
never import a generated program unit from an aspect a declaration already
routes. Why one channel:
[the standalone home model](../../../docs/explanation/standalone-homes.md).

## The machinery beneath: the dendritic substrate

Every `.nix` file under `modules/` is auto-imported by **import-tree** as a
flake-parts module — adding a feature is adding a file (names starting with
`_` are ignored; flake eval ignores *untracked* files, so `git add` new
ones). Features publish reusable pieces as **aspects** at
`flake.modules.<class>.<name>` (`nixos`, `darwin`, `homeManager`, `generic`);
same-name definitions merge. The declaration generators ride this substrate
and emit aspects into it; hand-written aspects sit beside them, first-class.
Details: [the flake machinery](../../../docs/explanation/flake-machinery.md).

`flake.nix` is **auto-generated** by flake-file (`DO-NOT-EDIT` banner) —
never hand-edit it.

## Repository layout

```
flake.nix        # auto-generated — never hand-edit
docs/            # the Diátaxis documentation tree
modules/
  nix/
    flake-parts/ # flake machinery: declarations/{programs,hosts,users}.nix, dendritic-tools
    tools/       # one feature per Nix tool (home-manager, nixpkgs, stylix, …)
  hosts/         # one folder per machine: flake.hosts declaration + quirks aspect
  users/         # one folder per user: factory stamping + flake.users declaration + overrides
  programs/      # one folder per program: its flake.programs declaration (and any hand-written aspects)
  services/      # daemons — hand-written aspects
  host-config/   # machine-level aspects (audio, network, …) and roles/ (baseline aggregates)
  factory/       # the user factory
  config/        # misc config features
secrets/         # sops-encrypted data
specs/           # transient design docs
wallpapers/      # wallpaper images referenced by stylix/hosts
```

Per-directory map:
[feature index](../../../docs/reference/feature-index.md).

## How to do things

Every kind of edit, with the page that carries the depth:

- **Add a program** — write `flake.programs.<name>` in
  `modules/programs/<name>/`; pick install ways, `config`, and
  `hasEnableOption`/`packages`/`handWritten` where needed.
  [Add a program](../../../docs/how-to/declarations/add-a-program.md).
- **Add a host** — one `configuration.nix` with the `flake.hosts` declaration
  plus a hand-written quirks aspect (`hostConstants` values, role imports,
  config-group members). [Add a host](../../../docs/how-to/declarations/add-a-host.md);
  guided: [new-machine walkthrough](../../../docs/tutorials/new-machine-walkthrough.md).
- **Add a user** — macOS account first (imperative), then the factory
  stamping in `modules/users/<user>/`, then list the user in
  `flake.hosts.<h>.users` — the single authority for account, baseline, and
  home output. [Add a user](../../../docs/how-to/declarations/add-a-user.md).
- **Make a program global on a host** — one `globalPrograms` entry on the
  host's declaration; the generator routes both halves.
  [Add a program §3](../../../docs/how-to/declarations/add-a-program.md),
  [schema: globalPrograms](../../../docs/reference/declaration-schema.md#globalprograms).
- **Override a program's install way per-host** — the host's
  `installOverrides` map (e.g. cedar's `installOverrides.firefox = "cask"`);
  it reroutes both halves and user-declaration resolution honors it.
  [Install-way resolution](../../../docs/explanation/install-way-resolution.md).
- **Add a per-user(-per-host) program** — `flake.users."<u>".programs` or
  `.hosts.<h>.programs` in the user's folder; entries resolve to the per-user
  way or filter/throw per the table in
  [Add a per-user program](../../../docs/how-to/declarations/add-a-per-user-program.md).
- **Override a program default per-user** — plain assignment in
  `modules/users/<user>/` (priority 100) beats the boundary-wrapped shared
  defaults (900); no `mkForce` needed.
  [The framework's why](../../../docs/explanation/declaration-framework.md).
- **Opt out of a global program** — `programs.<name>.enable = false;` in the
  user's folder.
  [Generated units: per-user opt-out](../../../docs/reference/generated-units.md#per-user-opt-out).
- **Write or edit a hand-written aspect** — for services/daemons and oddballs
  beyond declarations; follow the rules below and the pattern catalog in
  [`aspects.md`](aspects.md).
- **Add a service/daemon** — a hand-written aspect under `modules/services/`
  (or `modules/host-config/` for machine-level plumbing), imported by the
  hosts or roles that run it; declarations don't cover services.
- **Touch roles and baselines** — roles live in `modules/host-config/roles/`
  as aggregate aspects (`role-minimal`, `role-default`, `role-desktop`,
  `niri-desktop`); their homeManager aggregates reach homes only
  through a host declaration's `baselines` list.
  [Feature index](../../../docs/reference/feature-index.md).
- **Add a flake input** — never edit `flake.nix`; add it to the feature's
  `flake-file.inputs`, then `nix run .#write-flake`.
  [The flake machinery](../../../docs/explanation/flake-machinery.md).
- **Add a secret** — sops-nix + age, never plaintext in `.nix` files.
  [Add a secret](../../../docs/how-to/declarations/add-a-secret.md).
- **Rebuild a home** — the user runs `hr` (never you; see Validating).
  [Rebuild your home](../../../docs/how-to/rebuild-your-home.md).
- **Read host facts** — `config.hostConstants.<fact>` from any class; hosts
  set values in their quirks aspect; homes get them via the read-through.
  [Host facts](../../../docs/explanation/host-facts.md).

## Writing hand-written aspects: the rules

When you define `flake.modules.<class>.<name>`:

1. **Reference other aspects** via `inputs.self.modules.<class>.<name>`,
   usually through `imports = with inputs.self.modules.<class>; [ … ];`.
2. **Imports are typed by class.** A `nixos` aspect imports only `nixos`
   aspects; for NixOS *and* Darwin, define it `generic` and import that.
3. **Never import conditionally.** `imports = lib.mkIf …` breaks evaluation;
   make the imported module's *content* conditional (`lib.mkMerge` +
   `lib.mkIf`) instead.
4. **One channel per program/home.** Never import a generated program unit
   that a declaration already delivers (via `globalPrograms` or a user
   declaration) — double delivery concatenates list options.
5. **Merge with `lib.mkMerge`, not `//`.** `//` is a shallow overwrite.
6. **Detect the platform with `pkgs.stdenv.isLinux` / `isDarwin`**, not
   hand-rolled flags.

The recurring aspect shapes — Declaration, Simple, Inheritance, Conditional,
Collector, Constants, DRY, Factory — are cataloged with code in
[`aspects.md`](aspects.md). Read it before building anything non-trivial.

## Validating changes

Dry-build only — never activate, never push (see `AGENTS.md`):

```sh
nix flake check
nix build .#nixosConfigurations.<host>.config.system.build.toplevel --no-link      # NixOS (redwood, spruce)
nix build .#darwinConfigurations.<host>.system --no-link                           # macOS (aspen, cedar)
nix build '.#homeConfigurations."<user>@<host>".activationPackage' --no-link       # any touched home
nix run .#write-flake                    # after adding/removing flake inputs
```

- **On a Mac, NixOS hosts can't be built** (no Linux builder) — validate them
  by evaluation instead:
  `nix eval .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath`.
- **Always pass `--no-link`** — a `./result` symlink fails in this root-owned
  repo with a spurious `Permission denied` after the build succeeded.
- **`git add` new files first** — flake eval ignores untracked files, so an
  unstaged new module surfaces as a misleading "attribute missing".
- Format Nix with **`alejandra`** (2-space indent). Do **not** run `switch`,
  `nix flake update`, or the `nr`/`nrr`/`hr` shell functions yourself — those
  activate live systems (and `nr` pushes to GitHub).

## References

- [`aspects.md`](aspects.md) — the aspect design patterns, with code.
- `docs/` — the full Diátaxis tree (tutorials, how-to, reference, explanation).
- `AGENTS.md` — repo-wide cautions (root-owned paths, rebuild/push flow, secrets).
- Dendritic pattern origin: <https://github.com/mightyiam/dendritic>

## Related skills

- [[skill:repo-permissions]] — editing this root-owned repo without sudo (the `config` group)
- [[skill:nvf]] — Neovim built as its own flake, wired in as a feature
- [[skill:default-apps]] — setting default file/URL handlers via a cross-platform aspect
