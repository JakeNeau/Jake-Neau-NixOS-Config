{inputs, ...}: {
  # Nix User Repository: community packages (e.g. firefox/librewolf addons).
  # https://github.com/nix-community/NUR

  flake-file.inputs.nur.url = "github:nix-community/NUR";

  flake.modules.nixos.nur = {
    nixpkgs.overlays = [inputs.nur.overlays.default];
  };
}
