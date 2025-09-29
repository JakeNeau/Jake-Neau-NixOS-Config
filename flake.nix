{
  description = "NixOS top level flake";

  inputs = {
    # Version of nixpkgs for installing software
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Declarative management of the home configuration
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Apply common styling options shared across many home manager modules
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Nix user repository: packages not on nixpkgs
    nur.url = "github:nix-community/NUR";
    # Declarative Neovim
    nvf.url = "github:notashelf/nvf";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    minegrub-theme.url = "github:Lxtharia/minegrub-theme";
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
	home-manager.nixosModules.home-manager {
	  home-manager.useGlobalPkgs = true;
	  home-manager.useUserPackages = true;
	  home-manager.users.jakeneau = import ./users/jakeneau/home.nix;
	  nixpkgs.overlays = [
            inputs.nur.overlays.default
	  ];
	}
	inputs.stylix.nixosModules.stylix
	inputs.nvf.nixosModules.default
        inputs.sops-nix.nixosModules.sops
        inputs.minegrub-theme.nixosModules.default
      ];
    };
  };
}
