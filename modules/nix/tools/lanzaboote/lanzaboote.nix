{ inputs, ... }: {
  flake-file.inputs.lanzaboote = {
    url = "github:nix-community/lanzaboote/v1.1.0";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  flake.modules.nixos.lanzaboote =
    {
      lib,
      pkgs,
      ...
    }:
    let
      # rust-overlay still reads deprecated stdenv aliases.
      # Remove this compatibility set after it uses hostPlatform.
      rustOverlayCompatPkgs = pkgs // {
        callPackage = lib.callPackageWith rustOverlayCompatPkgs;
        stdenv = pkgs.stdenv // {
          inherit (pkgs.stdenv.hostPlatform) isDarwin isLinux;
        };
      };
      lanzaboote = import inputs.lanzaboote {
        pkgs = rustOverlayCompatPkgs;
        crane = inputs.lanzaboote.inputs.crane.mkLib rustOverlayCompatPkgs;
        rust-overlay = inputs.lanzaboote.inputs.rust-overlay.outPath;
      };
    in
    {
      imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

      environment.systemPackages = [ pkgs.sbctl ];

      boot.loader = {
        efi.canTouchEfiVariables = true;
        systemd-boot.enable = lib.mkForce false;
      };

      boot.lanzaboote = {
        enable = true;
        package = lanzaboote.packages.lzbt;
        pkiBundle = "/var/lib/sbctl";
      };
    };
}
