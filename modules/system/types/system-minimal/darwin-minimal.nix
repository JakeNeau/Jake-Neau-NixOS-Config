{
  # Baseline settings every nix-darwin system needs.
  flake.modules.darwin.system-minimal = {pkgs, ...}: {
    nixpkgs.config.allowUnfree = true;

    nix.settings.experimental-features = ["nix-command" "flakes"];

    environment.systemPackages = [pkgs.vim];

    # Used for backwards compatibility; read the changelog before changing.
    system.stateVersion = 6;
  };
}
