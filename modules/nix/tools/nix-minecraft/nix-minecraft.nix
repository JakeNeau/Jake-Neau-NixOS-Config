{inputs, ...}: {
  # Declarative Minecraft servers. https://github.com/Infinidoge/nix-minecraft
  # The server definitions themselves live in the desktop host.

  flake-file.inputs.nix-minecraft.url = "github:Infinidoge/nix-minecraft";

  flake.modules.nixos.nix-minecraft = {
    imports = [inputs.nix-minecraft.nixosModules.minecraft-servers];
    nixpkgs.overlays = [inputs.nix-minecraft.overlay];

    # Set-by-import: importing this feature means "this host runs a minecraft
    # server" — the fact beside the enable keeps the two in lockstep (fish's
    # mc-* helpers branch on it from standalone homes).
    services.minecraft-servers.enable = true;
    hostConstants.minecraftServer = true;
  };
}
