{inputs, ...}: {
  # Manage a user environment with Nix.
  # https://github.com/nix-community/home-manager

  flake-file.inputs = {
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  imports = [inputs.home-manager.flakeModules.home-manager];
}
