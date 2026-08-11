{inputs, ...}: {
  flake-file.inputs.grub2-themes = {
    url = "git+https://github.com/vinceliuice/grub2-themes.git";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  flake.modules.nixos.grub = {config, ...}: let
    resolution = config.hostConstants.displayResolution;
  in {
    imports = [inputs.grub2-themes.nixosModules.default];

    boot.loader = {
      efi.canTouchEfiVariables = true;
      grub = {
        enable = true;
        device = "nodev";
        efiSupport = true;
      };
      grub2-theme = {
        enable = true;
        theme = "tela";
        icon = "color";
        footer = true;
        customResolution = "${toString resolution.horizontal}x${toString resolution.vertical}";
      };
    };

    stylix.targets.grub.enable = false;
  };
}
