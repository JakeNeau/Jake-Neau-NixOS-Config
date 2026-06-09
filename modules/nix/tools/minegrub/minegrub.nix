{inputs, ...}: {
  # Minecraft-themed GRUB. https://github.com/Lxtharia/minegrub-theme
  # The theme is configured on the bootloader in the desktop host.

  flake-file.inputs.minegrub-theme.url = "github:Lxtharia/minegrub-theme";

  flake.modules.nixos.minegrub = {
    imports = [inputs.minegrub-theme.nixosModules.default];
  };
}
