{
  inputs,
  lib,
  ...
}: {
  # Every standalone home evaluates its own nixpkgs, so the shared nixpkgs
  # policy the home-manager system module used to provide (useGlobalPkgs)
  # must arrive explicitly — import this into every stamped home.
  #
  # The explicit mkOverride 100 markers below are plain priority, but the
  # marker makes the boundary wrapper leave these defs alone — necessary
  # because homeManagerConfiguration itself defines nixpkgs.overlays (plain,
  # from the passed pkgs), and a 900-stamped list would be discarded
  # wholesale; nixpkgs.config's opaque type never discharges markers stamped
  # inside its value, so it takes one marker at the option position.
  flake.modules.homeManager.common-nixpkgs = {
    nixpkgs.config = lib.mkOverride 100 {allowUnfree = true;};

    # NUR is genuinely needed by homes (e.g. firefox-family addons come
    # from pkgs.nur.repos.rycee). nix-minecraft's overlay stays at the
    # system layer — no home consumes it. No permittedInsecurePackages
    # pins: the only live pin (bitwarden-desktop's electron) is
    # system-installed.
    nixpkgs.overlays = lib.mkOverride 100 [inputs.nur.overlays.default];

    # standalone homes need the home-manager CLI on PATH to switch themselves
    programs.home-manager.enable = true;
  };
}
