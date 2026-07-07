{inputs, ...}: {
  # Baseline settings every NixOS system needs.
  flake.modules.nixos.system-minimal = {
    imports = [inputs.self.modules.generic.system-minimal];

    nixpkgs.config.allowUnfree = true;

    # Stamp each generation with the git commit it was built from
    # (dirtyRev when the tree has uncommitted changes).
    # Shown by `nixos-version --configuration-revision`.
    system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or null;

    # Users are managed declaratively (passwords via sops-nix).
    users.mutableUsers = false;
  };
}
