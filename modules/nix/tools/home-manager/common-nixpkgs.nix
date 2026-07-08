{
  inputs,
  lib,
  ...
}: {
  # Every standalone home evaluates its own nixpkgs, so the shared nixpkgs
  # policy the home-manager system module used to provide (useGlobalPkgs)
  # must arrive explicitly — import this into every stamped home.
  flake.modules.homeManager.common-nixpkgs = {
    # mkOverride 100 is plain priority; the explicit marker stops the
    # boundary wrapper recursing into the attrset, whose opaque option
    # type would never discharge markers stamped inside its value.
    nixpkgs.config = lib.mkOverride 100 {allowUnfree = true;};

    # NUR is genuinely needed by homes (e.g. firefox-family addons come
    # from pkgs.nur.repos.rycee). nix-minecraft's overlay stays at the
    # system layer — no home consumes it. No permittedInsecurePackages
    # pins: the only live pin (bitwarden-desktop's electron) is
    # system-installed. No marker needed here: the wrapper exempts lists.
    nixpkgs.overlays = [inputs.nur.overlays.default];

    # standalone homes need the home-manager CLI on PATH to switch themselves
    programs.home-manager.enable = true;
  };
}
