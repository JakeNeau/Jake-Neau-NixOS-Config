{inputs, ...}: let
  # System-side wiring: declare the options at the system level and forward
  # the resolved values to every user's home-manager config (which gets the
  # declarations via homeManager.role-default).
  declare-and-forward = {config, ...}: {
    imports = [inputs.self.modules.generic.host-constants];

    home-manager.sharedModules = [
      {hostConstants = config.hostConstants;}
    ];
  };
in {
  # Constants pattern: facts about a host, declared once and readable from any
  # feature in any class (system config and home-manager). A host states what
  # it *is* (e.g. hostConstants.isLaptop = true) and features branch on the
  # fact, instead of minting per-variant aspects per feature.
  #
  # Imported everywhere via role-default; hosts only set the values.
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

  flake.modules.nixos.host-constants = declare-and-forward;
  flake.modules.darwin.host-constants = declare-and-forward;
}
