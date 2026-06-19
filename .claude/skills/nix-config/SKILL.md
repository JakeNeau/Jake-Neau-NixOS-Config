---
name: nix-config
description: How this Nix configuration is structured and how to work in it. A single flake-parts flake defines NixOS and macOS (nix-darwin) systems plus home-manager using the dendritic pattern, where every feature is a module and hosts/users are themselves features composed of smaller ones. Use when adding, editing, or understanding anything here — features/aspects, module classes, hosts, users, programs, services, secrets, flake inputs, or the flake wiring.
---

# How this Nix configuration works

This repository is **one Nix flake** that fully defines Jake's machines across
**NixOS** (Linux) and **nix-darwin** (macOS), with program configuration pushed
through **home-manager** wherever possible. It is organized with the **dendritic
pattern** on top of **[flake-parts](https://flake.parts)**, following the guide at
<https://github.com/Doc-Steve/dendritic-design-with-flake-parts>.

> This describes how the configuration is *meant* to be structured (the repo is
> mid-migration to this pattern). When you add or change configuration, follow this
> structure, not any older monolithic layout still in the tree.

## The mental model: bottom-up features

The dendritic pattern inverts the usual top-down config.

- **Top-down (old):** create a *host*, then hang services, packages, and user
  settings off it. Cross-platform sharing means copy-paste or ad-hoc conditionals.
- **Bottom-up (this repo):** define a **feature** once — describing what it does in
  each context (NixOS, Darwin, home-manager) — then *use* it on any host. Hosts and
  users are themselves just features that import other features.

So the unit of code is the **feature**, not the host. Adding `syncthing` to a
machine, or porting a program to macOS, is a one-line import or a small new block —
never a refactor.

### Vocabulary

- **Feature** — a `.nix` file under `modules/`. Every such file is a flake-parts
  (*`flake`-class*) module. It defines one or more *aspects* and may also set
  flake-level outputs ("boilerplate").
- **Aspect** — a module for a specific context, stored at
  `flake.modules.<class>.<name>`. The reusable building block.
- **Module class** — the context an aspect targets: `nixos`, `darwin`,
  `homeManager`, or `generic` (usable in any class). **Imports are typed by
  class** — you cannot import a `darwin` aspect into a `nixos` one.
- **Enabling = importing.** There is no `enable = true` on a feature; you turn it
  on by importing its aspect, whose own code enables whatever it configures.

A single feature file can define aspects for several classes at once:

```nix
{
  flake.modules.nixos.basicPackages = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [git];
  };

  flake.modules.darwin.basicPackages = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [git];
  };

  flake.modules.homeManager.basicPackages = {
    programs.git.enable = true;
  };
}
```

## Repository layout

All features live under `modules/`. Everything in that tree is a feature module,
**imported automatically** — no `default.nix` files, no manual import lists.

```
flake.nix              # auto-generated — do not hand-edit (see below)
modules/
  nix/
    flake-parts/       # the flake-parts + dendritic setup and the helper library
    tools/             # one feature per Nix tool (home-manager, secrets, …)
  hosts/               # one feature per machine (NixOS or Darwin)
  users/               # one feature per user
  programs/            # apps, usually shared across platforms
  services/            # daemons / system services
  system/              # base "system type" features + low-level settings
secrets/               # sops-nix encrypted data (lives outside modules/)
packages/              # local package definitions (live outside modules/)
```

The grouping directories (`hosts`, `programs`, …) are **organizational only** —
Nix ignores them; they just help you find things. Add more (`gaming/`, `desktop/`,
…) freely.

### File & directory naming

- A feature is **named by its path**, so naming is documentation. Keep a feature's
  internal references independent of its location (relative paths, not hard-coded
  directory names).
- A small feature is a single `<name>.nix`. When it grows, make a **directory
  named after the feature** and split it by class — `nixos.nix`, `darwin.nix`,
  `generic.nix` — or `flake-parts.nix` (boilerplate). flake-parts merges them all,
  so splitting is free and aids maintenance.
- The upstream guide tags feature directories with the contexts they cover:
  **`[N]`**ixOS, **`[D]`**arwin; lowercase **`[n]`/`[d]`** mean home-manager on that
  platform (e.g. `browser [nd]`, `ssh [ND]`). Human convention only — optional, but
  handy for scanning the tree.
- Names starting with `_` are **ignored** by the importer — use them to park
  unfinished work or non-feature files.

## How the flake is assembled

`flake.nix` is **auto-generated** by [`vic/flake-file`] and opens with a
`DO-NOT-EDIT` banner. Its entire `outputs` is one line:

```nix
outputs = inputs: inputs.flake-parts.lib.mkFlake {inherit inputs;} (inputs.import-tree ./modules);
```

[`vic/import-tree`] recursively imports every `.nix` under `modules/`. The setup
itself lives in the `modules/nix/flake-parts/` feature:

```nix
{inputs, ...}: {
  flake-file.inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-file.url = "github:vic/flake-file";
    import-tree.url = "github:vic/import-tree";
  };

  imports = [
    inputs.flake-parts.flakeModules.modules
    inputs.flake-file.flakeModules.default
  ];

  systems = ["aarch64-darwin" "aarch64-linux" "x86_64-darwin" "x86_64-linux"];
}
```

### Adding a flake input

Don't edit `flake.nix` directly. Add the input to a feature's `flake-file.inputs`
(co-located with the feature that needs it), then regenerate:

```sh
nix run .#write-flake
```

### Turning aspects into real configurations

A small helper library (`flake.lib`, defined in the `nix/flake-parts` feature)
builds the actual system outputs from aspects:

```nix
mkNixos = system: name: {
  ${name} = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      inputs.self.modules.nixos.${name}
      {nixpkgs.hostPlatform = lib.mkDefault system;}
    ];
  };
};
# mkDarwin and mkHomeManager are analogous (darwinSystem / homeManagerConfiguration).
```

A host feature wires itself into the flake outputs with a one-line boilerplate
(kept in that feature's `flake-parts.nix`):

```nix
{inputs, ...}: {
  flake.darwinConfigurations = inputs.self.lib.mkDarwin "aarch64-darwin" "macbook";
}
```

(nix-darwin has no flake-parts module yet, so the repo declares the
`flake.darwinConfigurations` option itself inside the `nix/flake-parts` feature.)

## Writing aspects: the rules

When you define `flake.modules.<class>.<name>`:

1. **Reference other aspects** via `inputs.self.modules.<class>.<name>`, usually
   through `imports = with inputs.self.modules.<class>; [ … ];`.
2. **Imports are typed by class.** A `nixos` aspect can only import `nixos`
   aspects. For something shared by NixOS *and* Darwin, define it under the
   `generic` class and import that.
3. **Never import conditionally.** `imports = lib.mkIf …` breaks Nix evaluation.
   Make the *imported module's content* conditional instead (below), or restructure
   so the import is unconditional.
4. **Import each aspect at most once** along a given hierarchy path — double imports
   cause surprising merges (especially via `home-manager.sharedModules`).
5. **Merge with `lib.mkMerge`, not `//`.** `//` is a shallow overwrite; module
   values must merge recursively.
6. **Detect the platform with `pkgs.stdenv.isLinux` / `pkgs.stdenv.isDarwin`**, not
   hand-rolled flags — most useful inside cross-platform home-manager aspects.

Conditional content (the condition wraps the *content*, never the import):

```nix
flake.modules.homeManager.office = {pkgs, lib, ...}:
  lib.mkMerge [
    {home.packages = with pkgs; [notesnook];} # all platforms
    (lib.mkIf pkgs.stdenv.isLinux {home.packages = [pkgs.libreoffice-qt6];})
    (lib.mkIf pkgs.stdenv.isDarwin {home.packages = [pkgs.libreoffice-bin];})
  ];
```

## Common recipes

**Installing a program — always under `modules/programs/`, never inline on a host
or system type.** Define the app as its own feature (one aspect per class), then
*import* that feature into the relevant system. This keeps every app reusable and
discoverable in one place; reach for an inline `environment.systemPackages` /
`home.packages` only when something is truly host-specific.

**A program/app shared across platforms** — one feature, one aspect per class:

```nix
# modules/programs/foo/foo.nix
{
  flake.modules.nixos.foo = {pkgs, ...}: {environment.systemPackages = [pkgs.foo];};
  flake.modules.darwin.foo = {pkgs, ...}: {environment.systemPackages = [pkgs.foo];};
}
```

Then add `foo` to the relevant host or system-type's `imports` (e.g. `sioyek` is
imported into `system-desktop`'s home-manager aspect, so every host using that
system type gets it). Prefer configuring programs in a `homeManager` aspect — this
repo is home-manager-first.

**A new host** — a feature that imports a base system type plus the features you
want, then a one-line boilerplate to expose it:

```nix
# modules/hosts/macbook/configuration.nix
{inputs, ...}: {
  flake.modules.darwin.macbook = {
    imports = with inputs.self.modules.darwin; [system-desktop bob];
    networking.hostName = "macbook";
  };
}
# modules/hosts/macbook/flake-parts.nix
{inputs, ...}: {
  flake.darwinConfigurations = inputs.self.lib.mkDarwin "aarch64-darwin" "macbook";
}
```

**A new user** — a feature defining the user across classes. Pulling home-manager
in from the system aspect is the *Multi-Context* pattern; sharing common settings
via a `homeManager` aspect lets the same user also work as a standalone
home-manager config. Repetitive users are good candidates for the *Factory*
pattern. See [`aspects.md`](aspects.md).

## The aspect design patterns

The guide names eight recurring patterns. Most features are just **Simple**
(independent aspects per class) or **Inheritance** (a feature that imports and
extends others). The full catalog with code — Simple, Multi-Context, Inheritance,
Conditional, Collector, Constants, DRY, Factory — is in [`aspects.md`](aspects.md).
Read it before building anything non-trivial (a new host/system type, parameterized
users, shared constants, network interfaces).

## Validating changes

Dry-build only — never activate, never push (see `CLAUDE.md`):

```sh
nix flake check
nix build .#nixosConfigurations.<host>.config.system.build.toplevel --no-link   # NixOS
nix build .#darwinConfigurations.<host>.system --no-link                        # macOS
nix run .#write-flake                   # after adding/removing flake inputs
```

Always use `--no-link` — the `nixos-rebuild build` / `darwin-rebuild build`
wrappers try to create a `./result` symlink in this root-owned repo, which fails
with a spurious `Permission denied` after the build has succeeded.

Format Nix with **`alejandra`** (2-space indent). Do **not** run `switch`,
`nix flake update`, or the `nr`/`nrr` shell functions yourself — those rebuild the
live system and push to GitHub. Secrets go through **sops-nix**, never as plaintext
in `.nix` files.

## References

- [`aspects.md`](aspects.md) — the eight aspect design patterns, with code.
- `CLAUDE.md` — repo-wide cautions (root-owned paths, rebuild/push flow, secrets).
- Upstream guide: <https://github.com/Doc-Steve/dendritic-design-with-flake-parts>
- Dendritic pattern origin: <https://github.com/mightyiam/dendritic>

[`vic/import-tree`]: https://github.com/vic/import-tree
[`vic/flake-file`]: https://github.com/vic/flake-file

## Related skills

- [[skill:repo-permissions]] — editing this root-owned repo without sudo (the `config` group)
- [[skill:nvf]] — Neovim built as its own flake, wired in as a feature
- [[skill:default-apps]] — setting default file/URL handlers via a cross-platform aspect
