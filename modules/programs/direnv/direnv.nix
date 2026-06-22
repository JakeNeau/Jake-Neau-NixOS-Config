{inputs, ...}: {
  # direnv: auto-loads a project's environment on cd, with nix-direnv caching
  # `use flake`/`use nix` so dev shells don't re-evaluate on every entry.
  #
  # One generic aspect suffices: nixpkgs ships an identical system-level
  # `programs.direnv` module for both NixOS and nix-darwin. The nixos/darwin
  # aspects just re-export it.
  flake.modules.generic.direnv = {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };

  flake.modules.nixos.direnv.imports = [inputs.self.modules.generic.direnv];
  flake.modules.darwin.direnv.imports = [inputs.self.modules.generic.direnv];
}
