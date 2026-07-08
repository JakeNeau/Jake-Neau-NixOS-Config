{inputs, ...}: {
  # Baseline settings every nix-darwin system needs.
  flake.modules.darwin.role-minimal = {pkgs, ...}: {
    imports = [inputs.self.modules.generic.role-minimal];

    nixpkgs.config.allowUnfree = true;

    # Stamp each generation with the git commit it was built from
    # (dirtyRev when the tree has uncommitted changes).
    # Shown by `darwin-version --configuration-revision`.
    system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

    environment.systemPackages = [pkgs.vim];

    # Used for backwards compatibility; read the changelog before changing.
    system.stateVersion = 6;
  };
}
