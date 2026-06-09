{
  # nix-darwin: declarative macOS system configuration.
  # https://github.com/nix-darwin/nix-darwin
  flake-file.inputs.nix-darwin = {
    url = "github:nix-darwin/nix-darwin/master";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
