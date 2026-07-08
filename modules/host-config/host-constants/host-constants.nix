{inputs, ...}: {
  # Constants pattern: facts about a host, declared once and readable from any
  # feature in any class (system config and home-manager). A host states what
  # it *is* (e.g. hostConstants.isLaptop = true) and features branch on the
  # fact, instead of minting per-variant aspects per feature.
  #
  # Imported everywhere via role-default (both the system classes and the
  # homeManager aggregate); hosts only set the values. Homes receive the
  # resolved values through the hosts generator's read-through of the
  # evaluated system config.
  flake.modules.generic.host-constants = {lib, ...}: {
    options.hostConstants = {
      hostName = lib.mkOption {
        type = lib.types.str;
        # No default: every host MUST declare its hostname.
        description = "This host's network hostname (sets networking.hostName).";
      };
      isLaptop = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether this host is battery powered (laptop hardware).";
      };
      localAi = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether this host runs the local-ai stack (llama-server).";
      };
      minecraftServer = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether this host runs the declarative minecraft server (nix-minecraft).";
      };
      graphicsType = lib.mkOption {
        type = lib.types.enum ["amd" "intel" "nvidia" "apple"];
        # No default: every host MUST declare its GPU vendor.
        description = ''
          This host's GPU vendor. The graphics modules under
          modules/host-config/graphics/ each self-activate on a match, so a host
          declares only the GPU it has.
        '';
      };
    };
  };

  flake.modules.nixos.host-constants.imports = [inputs.self.modules.generic.host-constants];
  flake.modules.darwin.host-constants.imports = [inputs.self.modules.generic.host-constants];
}
