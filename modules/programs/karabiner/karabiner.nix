{
  # Karabiner-Elements: the macOS key-remapping daemon. The app comes from
  # homebrew (the nixpkgs build cannot activate its system extension) and
  # needs one-time manual approval of its driver extension and
  # input-monitoring permissions in System Settings.
  #
  # The homeManager aspect is a collector: features contribute complex
  # modification rules through the `karabiner.rules` option and this aspect
  # renders them all into karabiner.json.

  flake.modules.darwin.karabiner = {
    homebrew.casks = ["karabiner-elements"];
  };

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
