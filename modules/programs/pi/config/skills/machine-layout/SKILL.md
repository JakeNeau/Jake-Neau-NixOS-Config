---
name: machine-layout
description: >
  Where all of the user's system and user configuration lives. One Nix flake in
  a root-owned repository, /etc/nixos on NixOS and /etc/nix-darwin on macOS,
  declares every machine, program, user home, and agent configuration. Use
  before changing anything about a machine, a program, Pi itself, or Neovim, to
  find where the change belongs and how the user applies it.
---

# The Nix configuration

One git repository is the root of all system configuration. Every machine is
configured declaratively by Nix from that one flake. NixOS configures the Linux
machines and nix-darwin configures the Macs. Nothing is set up imperatively.
To change a system, a program, or a user environment, edit the repository and
let the user rebuild. Never hand-tweak a running machine.

## Where the repository is

- NixOS: `/etc/nixos`
- macOS: `/etc/nix-darwin`

The same repository is checked out on each machine. Root owns it, and a
dedicated `config` group grants its members write access without `sudo`. If an
edit fails on permissions, report it instead of retrying.

## Hosts

| Host | Platform |
| --- | --- |
| cedar | macOS (nix-darwin) |
| aspen | macOS (nix-darwin) |
| redwood | NixOS |
| spruce | NixOS |

## What lives there

- `modules/hosts/<name>/`: what each machine is.
- `modules/users/<name>/`: each user's own program requests and overrides.
- `modules/programs/<name>/`: how each program installs and its shared config.
  Pi's own configuration ships from `modules/programs/pi/`. Neovim ships from
  `modules/programs/nvf/`.
- `modules/services/` and `modules/host-config/`: daemons and machine-level
  aspects.
- `docs/`: the Diátaxis documentation tree. Read it before the code for any
  high-level question.
- `secrets/`: sops-encrypted data.

[[skill:system-config]] holds the structure, the rules, and the procedure for
each kind of edit.

## How a change is applied

The user applies changes. The `nr` and `nrr` shell functions update flake
inputs, commit, push to the public GitHub repository, rebuild the system, and
reactivate the user's home. The `hr` function rebuilds one home. A rebuild is
system-wide and outward-facing, so never run `nr`, `nrr`, `hr`, a `switch`
command, or `nix flake update`. Validate with dry builds only and tell the user
exactly what to run.

## Related skills

- [[skill:system-config]]: the repository's structure, rules, and edit procedures
- [[skill:pi-config]]: Pi's own configuration inside the repository
- [[skill:neovim]]: Neovim configuration inside the repository
