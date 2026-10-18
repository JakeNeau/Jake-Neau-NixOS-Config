# DO-NOT-EDIT. This file was auto-generated using github:denful/flake-file.
# Use `nix run .#write-flake` to regenerate it.
{
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);

  inputs = {
    flake-file.url = "github:vic/flake-file";
    flake-parts.url = "github:hercules-ci/flake-parts";
    grub2-themes = {
      url = "git+https://github.com/vinceliuice/grub2-themes.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    import-tree.url = "github:vic/import-tree";
    kubectl-nvim = {
      url = "github:Ramilito/kubectl.nvim/v2.44.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents.url = "github:numtide/llm-agents.nix";
    mac-app-util = {
      url = "github:hraban/mac-app-util";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-browser-addons = {
      url = "github:andre4ik3/nix-browser-addons";
      inputs = {
        data.follows = "nix-browser-addons-data";
        nixpkgs.follows = "nixpkgs";
      };
    };
    nix-browser-addons-data = {
      url = "github:andre4ik3/nix-browser-addons/data";
      flake = false;
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nur.url = "github:nix-community/NUR";
    nvf.url = "github:notashelf/nvf";
    open-claude-in-chrome = {
      url = "github:noemica-io/open-claude-in-chrome";
      flake = false;
    };
    pi-acp = {
      url = "github:svkozak/pi-acp";
      flake = false;
    };
    pi-agent-browser-native = {
      url = "github:fitchmultz/pi-agent-browser-native";
      flake = false;
    };
    pi-anthropic-auth = {
      url = "github:gotgenes/pi-anthropic-auth";
      flake = false;
    };
    pi-claude-bridge = {
      url = "github:elidickinson/pi-claude-bridge";
      flake = false;
    };
    pi-subagents = {
      url = "github:nicobailon/pi-subagents";
      flake = false;
    };
    pi-tidy-tools = {
      url = "https://registry.npmjs.org/@mobrienv/pi-tidy-tools/-/pi-tidy-tools-0.5.4.tgz";
      flake = false;
    };
    pi-tidy-tools-semver = {
      url = "https://registry.npmjs.org/semver/-/semver-7.8.5.tgz";
      flake = false;
    };
    pi-usage = {
      url = "github:iefnaf/pi-usage";
      flake = false;
    };
    pi-usage-bar = {
      url = "github:ttiimmaahh/pi-usage-bar";
      flake = false;
    };
    pi-usage-limits = {
      url = "https://registry.npmjs.org/pi-usage-limits/-/pi-usage-limits-0.1.4.tgz";
      flake = false;
    };
    pi-web-access = {
      url = "github:nicobailon/pi-web-access";
      flake = false;
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
