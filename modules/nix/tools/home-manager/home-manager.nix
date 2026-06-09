{inputs, ...}: let
  # Shared home-manager wiring for both NixOS and Darwin systems.
  home-manager-config = {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      # Back up (and remove the backup of) any pre-existing dotfiles that would
      # otherwise block the first activation — important on the macs.
      backupFileExtension = "backup";
    };
  };
in {
  flake.modules.nixos.home-manager = {
    imports = [
      inputs.home-manager.nixosModules.home-manager
      home-manager-config
    ];
  };

  flake.modules.darwin.home-manager = {
    imports = [
      inputs.home-manager.darwinModules.home-manager
      home-manager-config
    ];
  };
}
