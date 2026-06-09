{inputs, ...}: {
  # Declarative Minecraft servers. https://github.com/Infinidoge/nix-minecraft
  # The server definitions themselves live in the desktop host.

  flake-file.inputs.nix-minecraft.url = "github:Infinidoge/nix-minecraft";

  flake.modules.nixos.nix-minecraft = {
    imports = [inputs.nix-minecraft.nixosModules.minecraft-servers];
    nixpkgs.overlays = [inputs.nix-minecraft.overlay];
  };
}
