{ inputs, ... }: {
  # Constants pattern: facts about a host, declared once and readable from any
  # feature in any class (system config and home-manager). A host states what
  # it *is* (e.g. hostConstants.isLaptop = true) and features branch on the
  # fact, instead of minting per-variant aspects per feature.
  #
  # Imported everywhere via role-default (both the system classes and the
  # homeManager aggregate); hosts only set the values. Homes receive the
  # resolved values through the hosts generator's read-through of the
  # evaluated system config.
  flake.modules.generic.host-constants = { lib, ... }: {
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
      minecraftServer = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether this host runs the declarative minecraft server (nix-minecraft).";
      };
      displayResolution = {
        horizontal = lib.mkOption {
          type = lib.types.ints.positive;
          description = "The primary display's horizontal resolution in pixels.";
        };
        vertical = lib.mkOption {
          type = lib.types.ints.positive;
          description = "The primary display's vertical resolution in pixels.";
        };
      };
      graphicsType = lib.mkOption {
        type = lib.types.enum [
          "amd"
          "intel"
          "nvidia"
          "apple"
        ];
        # No default: every host MUST declare its GPU vendor.
        description = ''
          This host's GPU vendor. The graphics modules under
          modules/host-config/graphics/ each self-activate on a match, so a host
          declares only the GPU it has.
        '';
      };
      # Set by each installed VPN's systemConfig, beside the enable that
      # installs it; read by the flake.programs excludeFromVpn machinery.
      vpn = {
        excludeCommands = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Linux: shell lines, one per VPN, that exclude the current shell
            process ($$) from that VPN. A line must not fail when its VPN is
            unavailable. Wrappers of excludeFromVpn programs run every line
            before exec'ing the program.
          '';
        };
        syncExcludedApps = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            macOS: commands, one per VPN, that take a state-file path followed
            by zero or more executable paths. Each makes its VPN exclude
            exactly those paths for the state file's owner and leaves other
            entries alone. System and home activation run every command.
          '';
        };
      };
    };
  };

  flake.modules.nixos.host-constants.imports = [ inputs.self.modules.generic.host-constants ];
  flake.modules.darwin.host-constants.imports = [ inputs.self.modules.generic.host-constants ];
}
