{ inputs, ... }:
{
  # Ungoogled Chromium: Chromium with Google integration and phone-home removed.

  # Pinned extension CRXs, republished daily; each flake.lock update takes the latest.
  flake-file.inputs = {
    nix-browser-addons = {
      url = "github:andre4ik3/nix-browser-addons";
      inputs.nixpkgs.follows = "nixpkgs";
      # Track the daily data branch, not the copy frozen in its own lock.
      inputs.data.follows = "nix-browser-addons-data";
    };
    nix-browser-addons-data = {
      url = "github:andre4ik3/nix-browser-addons/data";
      flake = false;
    };
  };

  flake.programs.ungoogled-chromium = {
    # nixpkgs builds Chromium only on Linux, so macOS takes the Homebrew cask.
    install.linux = [ "system" ];
    install.macos = [ "cask" ];
    # false: home-manager's module is programs.chromium, so the default would
    # null a programs.ungoogled-chromium.package option that does not exist.
    hasEnableOption = false;

    config =
      { pkgs, ... }:
      let
        # Applied to this home's pkgs; legacyPackages would instantiate a second nixpkgs.
        ublock = (inputs.nix-browser-addons.overlays.default pkgs pkgs).chromiumExtensions.ublock-origin;
      in
      {
        programs.chromium = {
          enable = true;
          # The browser is a system or cask install; home-manager only writes its config.
          package = null;
          # ungoogled-chromium never downloads extensions, so each one is a
          # local CRX whose version must equal its manifest's.
          extensions = [
            {
              id = ublock.passthru.id;
              inherit (ublock) version;
              crxPath = ublock;
            }
          ];
        };
      };
  };
}
