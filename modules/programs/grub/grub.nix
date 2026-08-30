{inputs, ...}: {
  flake-file.inputs.grub2-themes = {
    url = "git+https://github.com/vinceliuice/grub2-themes.git";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  flake.modules.nixos.grub = {lib, ...}: {
    imports = [inputs.grub2-themes.nixosModules.default];

    boot.loader = {
      efi.canTouchEfiVariables = true;
      grub = {
        enable = true;
        device = "nodev";
        efiSupport = true;
        gfxmodeEfi = lib.mkForce "auto";
      };
      grub2-theme = {
        enable = true;
        theme = "tela";
        icon = "color";
        footer = true;
        screen = "1080p";
      };
    };

    stylix.targets.grub.enable = false;
  };
}
