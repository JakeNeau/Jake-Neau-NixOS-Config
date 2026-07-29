{inputs, ...}: {
  # nix-homebrew: declarative Homebrew installation management for nix-darwin.
  # https://github.com/zhaofengli/nix-homebrew
  flake-file.inputs = {
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    # nix-homebrew pins Homebrew 6.0.12, whose Cask DSL lacks command_wrapper,
    # so casks served by Homebrew's JSON API fail to parse during activation.
    # Drop this override once upstream pins 6.0.13 or newer.
    nix-homebrew.inputs.brew-src.follows = "brew-src";
    brew-src = {
      url = "github:Homebrew/brew/6.0.13";
      flake = false;
    };
  };

  flake.modules.darwin.nix-homebrew = {
    imports = [inputs.nix-homebrew.darwinModules.nix-homebrew];

    # The importing host sets nix-homebrew.user (the account that owns the
    # Homebrew prefix) and its homebrew.* package lists.
    nix-homebrew.enable = true;
  };
}
