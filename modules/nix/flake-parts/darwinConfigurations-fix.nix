{
  lib,
  flake-parts-lib,
  ...
}: {
  # nix-darwin has no flake-parts module yet, so declare the
  # flake.darwinConfigurations option ourselves.

  options = {
    flake = flake-parts-lib.mkSubmoduleOptions {
      darwinConfigurations = lib.mkOption {
        type = lib.types.lazyAttrsOf lib.types.raw;
        default = {};
      };
    };
  };
}
