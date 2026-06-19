{inputs, ...}: {
  # Baseline settings every nix-darwin system needs.
  flake.modules.darwin.system-minimal = {pkgs, ...}: {
    imports = [inputs.self.modules.generic.system-minimal];

    nixpkgs.config.allowUnfree = true;
    # LibreWolf is flagged insecure because it lacks an active nixpkgs
    # committer, not for a CVE — a version bump won't clear this.
    nixpkgs.config.permittedInsecurePackages = [
      "librewolf-151.0.2-1"
      "librewolf-unwrapped-151.0.2-1"
    ];

    # Stamp each generation with the git commit it was built from
    # (dirtyRev when the tree has uncommitted changes).
    # Shown by `darwin-version --configuration-revision`.
    system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

    environment.systemPackages = [pkgs.vim];

    # Used for backwards compatibility; read the changelog before changing.
    system.stateVersion = 6;
  };
}
