{inputs, ...}: {
  # System-wide theming. https://github.com/danth/stylix
  # NixOS only here; the macs theme nvf directly (see programs/nvf).

  flake-file.inputs = {
    stylix.url = "github:danth/stylix";
    stylix.inputs.nixpkgs.follows = "nixpkgs";
  };

  flake.modules.nixos.stylix = {pkgs, ...}: {
    imports = [inputs.stylix.nixosModules.stylix];

    # Theme librewolf's default profile for any user with it enabled (NixOS;
    # the macs have no stylix). Lives here so the cross-platform user aspect
    # stays free of NixOS-only option namespaces.
    home-manager.sharedModules = [{stylix.targets.librewolf.profileNames = ["default"];}];

    stylix = {
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
  };
}
