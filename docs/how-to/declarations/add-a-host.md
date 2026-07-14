# Add a host

A host is one file, `modules/hosts/<host>/configuration.nix`, holding two
things: the `flake.hosts` declaration the generator wires everything from,
and a hand-written aspect for the machine's quirks. For the guided version,
see the [new-machine walkthrough](../../tutorials/new-machine-walkthrough.md).

## 1. Write the declaration

```nix
flake.hosts.<host> = {
  class = "nixos";                    # or "darwin"
  system = "x86_64-linux";
  users = ["<user>"];                 # accounts on this machine
  globalPrograms = ["ghostty" "fastfetch"];  # every user gets these
  # installOverrides.firefox = "cask";       # pick a non-default install way
  baselines = ["role-desktop"];       # aggregates inherited by the HM baseline
};
```

Field semantics:
[declaration schema reference](../../reference/declaration-schema.md). Existing
hosts to model on: `redwood`/`spruce` (NixOS), `aspen`/`cedar` (darwin) —
note cedar's `installOverrides.firefox = "cask"` for the override pattern and
the darwin hosts' `mac-app-util` baseline entry.

From this the generator stamps:

- `flake.modules.<class>.<host>-host-config` — the listed users' account
  aspects plus the system halves of `globalPrograms`;
- `flake.modules.homeManager.<host>-baseline` — the baseline every listed
  user's home imports: the `baselines` aggregates, each global program's HM
  half (the full unit, or `-config` for system-installed ones), and the
  `hostConstants` read-through;
- the flake outputs: `nixosConfigurations.<host>` /
  `darwinConfigurations.<host>` and `homeConfigurations."<user>@<host>"` for
  each listed user.

## 2. Write the hand-written aspect

In the same file, `flake.modules.<class>.<host>` carries what no declaration
covers:

- a role import (e.g. `inputs.self.modules.nixos.role-desktop`) and any
  feature imports (daemons, ...);
- `hostConstants.hostName` and `hostConstants.graphicsType` — **required, no
  defaults** — plus optional facts like `isLaptop`;
- **darwin:** the host's `users.groups.config.members` line (membership is
  per-host on macOS; on NixOS the list is central in
  `modules/host-config/config-group/config-group.nix`);
- **NixOS:** `system.stateVersion`, boot loader config, and the machine's
  hardware config in a sibling `modules/hosts/<host>/hardware.nix`
  contributing to the same aspect (see `modules/hosts/spruce/hardware.nix`).

## 3. Stage and dry-build

```sh
git add modules/hosts/<host>/
nix flake check
nix build .#nixosConfigurations.<host>.config.system.build.toplevel --no-link  # NixOS
nix build .#darwinConfigurations.<host>.system --no-link                       # macOS
nix build '.#homeConfigurations."<user>@<host>".activationPackage' --no-link   # each listed user
```

Then bootstrap the machine itself:
[Bootstrap a machine](../bootstrap-machine.md).
