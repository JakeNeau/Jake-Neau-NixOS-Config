{inputs, ...}: let
  # System-side wiring: declare the options at the system level and forward
  # the resolved values to every user's home-manager config (which gets the
  # declarations via homeManager.system-default).
  declare-and-forward = {config, ...}: {
    imports = [inputs.self.modules.generic.system-constants];

    home-manager.sharedModules = [
      {systemConstants = config.systemConstants;}
    ];
  };
in {
  # Constants pattern: facts about a host, declared once and readable from any
  # feature in any class (system config and home-manager). A host states what
  # it *is* (e.g. systemConstants.isLaptop = true) and features branch on the
  # fact, instead of minting per-variant aspects per feature.
  #
  # Imported everywhere via system-default; hosts only set the values.
  flake.modules.generic.system-constants = {lib, ...}: {
    options.systemConstants = {
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
      graphicsType = lib.mkOption {
        type = lib.types.enum ["amd" "intel" "nvidia" "apple"];
        # No default: every host MUST declare its GPU vendor.
        description = ''
          This host's GPU vendor. The graphics modules under
          modules/system/graphics/ each self-activate on a match, so a host
          declares only the GPU it has.
        '';
      };
    };
  };

  flake.modules.nixos.system-constants = declare-and-forward;
  flake.modules.darwin.system-constants = declare-and-forward;
}
