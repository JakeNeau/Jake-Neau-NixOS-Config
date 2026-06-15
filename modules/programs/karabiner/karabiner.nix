{
  # Karabiner-Elements: the macOS key-remapping daemon. The app comes from
  # homebrew (the nixpkgs build cannot activate its system extension) and
  # needs one-time manual approval of its driver extension and
  # input-monitoring permissions in System Settings.
  #
  # The homeManager aspect is a collector: features contribute complex
  # modification rules through the `karabiner.rules` option and this aspect
  # renders them all into karabiner.json.

  # --------------------------------
  # System install & first-run setup
  # --------------------------------
  flake.modules.darwin.karabiner = {config, ...}: {
    homebrew.casks = ["karabiner-elements"];

    # Karabiner's first-run approvals (driver extension + Input Monitoring)
    # cannot be automated. A fully set-up system has the Karabiner-Core-Service
    # daemon running AND the virtual HID driver extension approved; if either
    # is missing, nag on activation and launch the app to surface the macOS
    # prompts. (The daemon alone is not enough -- it already runs before the
    # driver is approved.)
    system.activationScripts.postActivation.text = ''
      if [ -d /Applications/Karabiner-Elements.app ]; then
        if ! /usr/bin/pgrep -qf Karabiner-Core-Service \
          || ! /usr/bin/systemextensionsctl list 2>/dev/null \
            | /usr/bin/grep -q "org.pqrs.Karabiner-DriverKit-VirtualHIDDevice.*activated enabled"; then
          printf '\n\033[1;33mwarning:\033[0m Karabiner-Elements is installed but not fully set up.\n'
          echo "Launching it now -- approve the driver extension and Input Monitoring in"
          echo "System Settings > Privacy & Security so the karabiner.json rules apply."
          sudo -u ${config.system.primaryUser} /usr/bin/open -a Karabiner-Elements || true
        fi
      fi
    '';
  };

  # --------------------------------
  # Rules collector & karabiner.json
  # --------------------------------
  flake.modules.homeManager.karabiner = {
    config,
    pkgs,
    lib,
    ...
  }: {
    options.karabiner.rules = lib.mkOption {
      type = lib.types.listOf (pkgs.formats.json {}).type;
      default = [];
      description = "Karabiner-Elements complex modification rules, merged into karabiner.json.";
    };

    # Karabiner reads this file live. As a read-only store symlink it works
    # fine, but edits made in the Karabiner GUI will not stick -- change the
    # contributing feature instead.
    config = lib.mkIf pkgs.stdenv.isDarwin {
      xdg.configFile."karabiner/karabiner.json".text = builtins.toJSON {
        profiles = [
          {
            name = "Default";
            selected = true;
            virtual_hid_keyboard.keyboard_type_v2 = "ansi";
            complex_modifications.rules = config.karabiner.rules;
          }
        ];
      };
    };
  };
}
