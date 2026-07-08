# The common nixpkgs module

`flake.modules.homeManager.common-nixpkgs`
(`modules/nix/tools/home-manager/common-nixpkgs.nix`): the shared nixpkgs
policy imported into every stamped home (see [generated host
artifacts](generated-host-artifacts.md)). Each standalone home evaluates
its own nixpkgs, so this policy must arrive explicitly; why homes are
standalone at all: [the standalone home
model](../explanation/standalone-homes.md).

## What it sets

- `nixpkgs.config = { allowUnfree = true; }` — the shared unfree
  permission.
- `nixpkgs.overlays = [ inputs.nur.overlays.default ]` — the NUR overlay,
  needed by homes (firefox-family addons come from
  `pkgs.nur.repos.rycee`). The nix-minecraft overlay is not included: no
  home consumes it, so it stays at the system layer.
- No `permittedInsecurePackages` pins: the only live pin
  (bitwarden-desktop's electron) is system-installed.
- `programs.home-manager.enable = true` — every home ships the
  `home-manager` CLI, which `hr` and self-managed switching need.

## Priority markers

Both `nixpkgs.config` and `nixpkgs.overlays` carry an explicit
`lib.mkOverride 100` marker. 100 is plain priority — the marker changes
nothing about merging. The boundary priority wrapper leaves explicitly
marked definitions untouched; the rationale for marking these two options:
[the framework's why](../explanation/declaration-framework.md).
