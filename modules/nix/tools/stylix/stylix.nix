{inputs, ...}: let
  # Theme values shared by the NixOS aspect and the homeManager aspect, so
  # both layers state the same theme. A function of pkgs because the cursor
  # and fonts reference packages.
  theme = pkgs: {
    enable = true;

    base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-material-dark-hard.yaml";
    polarity = "dark";

    image = ../../../../wallpapers/mountain-sunset.jpg;

    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 24;
    };

    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.lilex;
        name = "Lilex Nerd Font Mono";
      };
      sansSerif = {
        package = pkgs.montserrat;
        name = "Montserrat";
      };
      serif = {
        package = pkgs.zilla-slab;
        name = "Zilla Slab";
      };
    };
  };
in {
  # System-wide theming. https://github.com/danth/stylix
  # Linux only: the NixOS aspect themes the system layer, the homeManager
  # aspect (in the Linux hosts' baselines) themes standalone homes. macOS
  # theming is out of scope for now (the macs theme nvf directly; see
  # programs/nvf and TODO.md).

  flake-file.inputs = {
    stylix.url = "github:danth/stylix";
    stylix.inputs.nixpkgs.follows = "nixpkgs";
  };

  flake.modules.nixos.stylix = {
    lib,
    pkgs,
    ...
  }: {
    imports = [inputs.stylix.nixosModules.stylix];
    stylix = lib.mkMerge [
      (theme pkgs)
      {targets.regreet.enable = false;}
    ];
  };

  flake.modules.homeManager.stylix = {
    lib,
    pkgs,
    ...
  }: {
    imports = [inputs.stylix.homeModules.stylix];
    stylix = lib.mkMerge [
      (theme pkgs)
      {
        targets = {
          hyprland.enable = false;
          librewolf.profileNames = [
            "work"
            "strict"
            "compatibility"
          ];
        };
      }
    ];
    home.pointerCursor.enable = true;
  };
}
