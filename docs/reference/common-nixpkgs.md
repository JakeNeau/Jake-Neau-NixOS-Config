# The common nixpkgs module

`flake.modules.homeManager.common-nixpkgs` is the shared nixpkgs policy for
every stamped home. Its source is
`modules/nix/tools/home-manager/common-nixpkgs.nix`. See [generated host
artifacts](generated-host-artifacts.md).

Each standalone home evaluates its own nixpkgs. This policy must therefore
arrive explicitly. See [the standalone home
model](../explanation/standalone-homes.md).

## What it sets

- `nixpkgs.config.allowUnfree = true` grants the shared unfree permission.
- `nixpkgs.config.permittedInsecurePackages` permits
  `beekeeper-studio-6.0.5`. That release bundles EOL Electron 39.8.1. Remove
  the exception after nixpkgs updates Beekeeper Studio.
- `nixpkgs.overlays = [ inputs.nur.overlays.default ]` adds the NUR overlay.
  Homes need NUR for packages such as `pkgs.nur.repos.rycee` Firefox addons.
  The system layer retains the nix-minecraft overlay because no home uses it.
- `programs.home-manager.enable = true` adds the `home-manager` CLI to every
  home. Users need this CLI to run `hr` or switch their homes directly.

## Priority markers

`nixpkgs.config` carries an explicit `lib.mkOverride 100` marker. Priority 100
is the plain priority, so the marker does not change merging. The marker stops
the boundary priority wrapper from recursing into the attrset. The opaque
option type cannot discharge markers stamped inside its value.

`nixpkgs.overlays` needs no marker because the wrapper exempts lists. See [the
framework rationale](../explanation/declaration-framework.md).
