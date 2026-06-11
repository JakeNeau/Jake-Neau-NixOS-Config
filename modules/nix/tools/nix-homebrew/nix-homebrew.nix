{inputs, ...}: {
  # nix-homebrew: declarative Homebrew installation management for nix-darwin.
  # https://github.com/zhaofengli/nix-homebrew
  flake-file.inputs.nix-homebrew.url = "github:zhaofengli/nix-homebrew";

  flake.modules.darwin.nix-homebrew = {
    imports = [inputs.nix-homebrew.darwinModules.nix-homebrew];

    # The importing host sets nix-homebrew.user (the account that owns the
    # Homebrew prefix) and its homebrew.* package lists.
    nix-homebrew.enable = true;
  };
}
