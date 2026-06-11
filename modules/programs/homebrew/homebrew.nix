{inputs, ...}: {
  # Homebrew: macOS package manager for the stubborn packages that work better
  # outside nixpkgs (GUI casks like karabiner-elements, ghostty, firefox).
  # nix-homebrew installs and manages brew itself declaratively.
  flake.modules.darwin.homebrew = {config, ...}: {
    imports = [inputs.self.modules.darwin.nix-homebrew];

    # The Homebrew prefix is owned by the host's admin account.
    nix-homebrew.user = config.system.primaryUser;
    homebrew.enable = true;
  };
}
