{inputs, ...}: {
  # Baseline settings every nix-darwin system needs.
  flake.modules.darwin.system-minimal = {pkgs, ...}: {
    nixpkgs.config.allowUnfree = true;

    # Stamp each generation with the git commit it was built from
    # (dirtyRev when the tree has uncommitted changes).
    # Shown by `darwin-version --configuration-revision`.
    system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

    nix.settings.experimental-features = ["nix-command" "flakes"];

    environment.systemPackages = [pkgs.vim];

    # Used for backwards compatibility; read the changelog before changing.
    system.stateVersion = 6;
  };
}
