{inputs, ...}: {
  # Baseline settings every NixOS system needs.
  flake.modules.nixos.system-minimal = {
    imports = [inputs.self.modules.generic.system-minimal];

    nixpkgs.config.allowUnfree = true;
    # LibreWolf is flagged insecure because it lacks an active nixpkgs
    # committer, not for a CVE — a version bump won't clear this.
    nixpkgs.config.permittedInsecurePackages = [
      "electron-39.8.10" # bitwarden-desktop pins an EOL electron upstream.
      "librewolf-151.0.2-1"
      "librewolf-unwrapped-151.0.2-1"
    ];

    # Stamp each generation with the git commit it was built from
    # (dirtyRev when the tree has uncommitted changes).
    # Shown by `nixos-version --configuration-revision`.
    system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

    # Users are managed declaratively (passwords via sops-nix).
    users.mutableUsers = false;
  };
}
