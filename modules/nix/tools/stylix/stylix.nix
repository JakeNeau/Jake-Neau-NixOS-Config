{inputs, ...}: let
  # Theme values shared by the NixOS aspect and the homeManager aspect, so
  # both layers state the same theme. A function of pkgs because the cursor
  # and fonts reference packages.
  theme = pkgs: {
    enable = true;

    base16Scheme = "${pkgs.base16-schemes}/share/themes/everforest-dark-hard.yaml";
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
    config,
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
          # Replaced by the hand-wired nvf theming below.
          nvf.enable = false;
          librewolf.profileNames = [
            "work"
            "strict"
            "compatibility"
          ];
        };
      }
    ];
    home.pointerCursor.enable = true;

    # Stylix's nvf target still sets vim.statusline.lualine.theme, which nvf
    # renamed (warning on every eval). Same theming, new option name. Drop
    # this and re-enable the target once stylix PR #2497 lands.
    programs.nvf.settings.vim = {
      theme = {
        enable = true;
        name = "base16";
        base16-colors = {
          inherit
            (config.lib.stylix.colors.withHashtag)
            base00
            base01
            base02
            base03
            base04
            base05
            base06
            base07
            base08
            base09
            base0A
            base0B
            base0C
            base0D
            base0E
            base0F
            ;
        };
      };
      statusline.lualine.setupOpts.options.theme = "base16";
    };
  };
}
