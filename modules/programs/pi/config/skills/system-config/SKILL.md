---
name: system-config
description: >
  How the user's Nix configuration repository is structured, the rules for
  editing it, and the procedure for each kind of change. One flake-parts flake
  defines NixOS and nix-darwin machines through three declarations,
  flake.programs, flake.hosts, and flake.users, with every user's home a
  standalone home-manager configuration. Use before adding, editing, or
  understanding anything in the repository: programs, hosts, users, aspects,
  roles, services, secrets, flake inputs, or validation.
---

# Editing the system and program configuration

[[skill:nix-config]] states where the repository is and how the user applies
a change. This skill states how the repository is built and how to edit it.
The repository's `docs/` tree carries the depth. Read `docs/README.md` first,
then the page that this skill names for the task.

## The three declarations

All wiring is generated from three structured declarations:

- `flake.programs.<name>` in `modules/programs/<name>/` declares how a program
  installs per platform (`install.linux`: `home` or `system`, `install.macos`:
  `home` or `cask`) plus a shared home-manager `config` module. The generator
  emits `flake.modules` units for each class.
- `flake.hosts.<name>` in `modules/hosts/<host>/configuration.nix` declares
  `class`, `system`, `users`, `globalPrograms`, `installOverrides`, and
  `baselines`. The generator routes each global program by its install way and
  stamps the flake outputs.
- `flake.users.<name>` in `modules/users/<user>/` declares `programs` for all
  of the user's machines and `hosts.<h>.programs` for one machine. These
  resolve to home-manager units, never system installs.

Every user's home is a standalone output,
`homeConfigurations."<user>@<host>"`. It combines the user's own aspect, the
host's baseline, and the user's resolved declaration units. Shared config is
lowered to priority 900, so a user's plain assignment overrides it. Lists are
exempt and merge. Nothing else may deliver config to a home. Never import a
generated program unit from an aspect when a declaration already routes it.

Schema: `docs/reference/declaration-schema.md`. Rationale:
`docs/explanation/declaration-framework.md` and
`docs/explanation/standalone-homes.md`.

## The substrate beneath

import-tree auto-imports every `.nix` file under `modules/` as a flake-parts
module, so adding a feature is adding a file. It ignores names that start with
`_`. Flake evaluation ignores untracked files, so `git add` a new file before
you build.

Features publish reusable aspects at `flake.modules.<class>.<name>`, where the
class is `nixos`, `darwin`, `homeManager`, or `generic`. Same-name definitions
merge. Details: `docs/explanation/flake-machinery.md`.

flake-file generates `flake.nix`. Never hand-edit it. Declare an input in a
feature's `flake-file.inputs`, then run `nix run .#write-flake`.

## Repository layout

```
flake.nix        # generated, never hand-edit
docs/            # the Diátaxis documentation tree
modules/
  nix/           # flake machinery and one feature per Nix tool
  hosts/         # one folder per machine
  users/         # one folder per user
  programs/      # one folder per program
  services/      # daemons, hand-written aspects
  host-config/   # machine-level aspects and roles/ (baseline aggregates)
  factory/       # the user factory
  config/        # misc config features
secrets/         # sops-encrypted data
specs/           # transient design documents
```

Per-directory map: `docs/reference/feature-index.md`.

## Rules

1. Simple and elegant above all. Use the existing idiom before inventing one.
2. Nix only. Use no other package manager.
3. home-manager first. Configure a program through home-manager whenever it can.
4. Never pin a version by hand. `flake.lock` pins everything.
5. Format Nix with `nix fmt` and match the 2-space indentation.
6. Keep secrets in `secrets/secrets.yaml` through sops. Never write a plaintext
   secret in a `.nix` file. Never commit `secrets/keys.txt`.
7. Record follow-up work only in the root `TODO.md`, and only when the user
   asks.

## How to do things

- Add a program: write `flake.programs.<name>` in `modules/programs/<name>/`.
  `docs/how-to/declarations/add-a-program.md`.
- Add a host: one `configuration.nix` with the `flake.hosts` declaration plus a
  quirks aspect. `docs/how-to/declarations/add-a-host.md`.
- Add a user: the factory stamping in `modules/users/<user>/`, then list the
  user in `flake.hosts.<h>.users`. `docs/how-to/declarations/add-a-user.md`.
- Make a program global on a host: one `globalPrograms` entry on the host.
- Override an install way per host: the host's `installOverrides` map.
  `docs/explanation/install-way-resolution.md`.
- Add a per-user program: `flake.users."<u>".programs` or `.hosts.<h>.programs`.
  `docs/how-to/declarations/add-a-per-user-program.md`.
- Override a program default per user: a plain assignment in
  `modules/users/<user>/`. No `mkForce` is needed.
- Opt out of a global home install: `programs.<name>.enable = false;` in the
  user's folder.
- Add a service or daemon: a hand-written aspect under `modules/services/`,
  imported by the hosts or roles that run it.
- Add a flake input: `flake-file.inputs` in the feature, then
  `nix run .#write-flake`.
- Add a secret: `docs/how-to/declarations/add-a-secret.md`.
- Read a host fact: `config.hostConstants.<fact>`.
  `docs/explanation/host-facts.md`.
- Change Pi's own configuration: follow [[skill:pi-config]].
- Change Neovim: follow [[skill:neovim]].

## Writing a hand-written aspect

1. Reference other aspects through `inputs.self.modules.<class>.<name>`.
2. Imports are typed by class. A `nixos` aspect imports only `nixos` aspects.
   For both platforms, define the aspect as `generic`.
3. Never import conditionally. Make the imported content conditional with
   `lib.mkMerge` and `lib.mkIf`.
4. One channel per program and home. Never import a generated unit that a
   declaration already delivers.
5. Merge with `lib.mkMerge`, not `//`.
6. Detect the platform with `pkgs.stdenv.hostPlatform.isLinux` or `isDarwin`.

The aspect shapes are cataloged with code in
`.agents/skills/nix-config/aspects.md`. Read it before building anything
non-trivial.

## Validate without activating

```sh
nix flake check
nix build .#nixosConfigurations.<host>.config.system.build.toplevel --no-link   # redwood, spruce
nix build .#darwinConfigurations.<host>.system --no-link                        # aspen, cedar
nix build '.#homeConfigurations."<user>@<host>".activationPackage' --no-link
```

Always pass `--no-link`. A `./result` symlink fails in this root-owned
repository after the build succeeds. A Mac has no Linux builder, so validate a
NixOS host there with `nix eval` on its `drvPath`. Never run `switch`,
`nix flake update`, `nr`, `nrr`, or `hr`.

## Related skills

- [[skill:nix-config]]: where the repository is and how the user applies a change
- [[skill:pi-config]]: Pi's own configuration inside the repository
- [[skill:neovim]]: Neovim configuration inside the repository
