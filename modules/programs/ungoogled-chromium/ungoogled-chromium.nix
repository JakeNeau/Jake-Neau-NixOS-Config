{
  # Ungoogled Chromium: Chromium with Google integration and phone-home removed.
  #
  # Split: nixpkgs only builds Chromium on Linux, so NixOS installs the
  # nixpkgs package while macOS pulls the Homebrew cask (as the other browsers
  # do there).
  flake.modules.nixos.ungoogled-chromium = {pkgs, ...}: {
    environment.systemPackages = [pkgs.ungoogled-chromium];
  };

  flake.modules.darwin.ungoogled-chromium = {
    homebrew.casks = ["ungoogled-chromium"];
  };
}
