{
  # Caps lock as a dual-role key on every system: ctrl when held with another
  # key, escape when tapped alone.
  #
  # NixOS  [N]: kanata grabs the real keyboards at the evdev level, so the
  #             remap works in Wayland, X, and the console alike.
  # macOS [Dd]: Karabiner-Elements (homebrew cask -- the nixpkgs build cannot
  #             activate its system extension) with a declarative
  #             karabiner.json from home-manager. The app's system extension
  #             and input-monitoring permissions still need one-time manual
  #             approval in System Settings.

  flake.modules.nixos.caps-dual-role = {
    services.kanata = {
      enable = true;
      keyboards.default = {
        # Needed so pressing any unmapped key can trigger the hold (ctrl)
        # branch of tap-hold-press early during fast chords.
        extraDefCfg = "process-unmapped-keys yes";
        config = ''
          (defsrc caps)
          (deflayer base (tap-hold-press 200 200 esc lctl))
        '';
      };
    };
  };

  flake.modules.darwin.caps-dual-role = {
    homebrew.casks = ["karabiner-elements"];
  };

  flake.modules.homeManager.caps-dual-role = {
    pkgs,
    lib,
    ...
  }:
    lib.mkIf pkgs.stdenv.isDarwin {
      xdg.configFile."karabiner/karabiner.json".text = builtins.toJSON {
        profiles = [
          {
            name = "Default";
            selected = true;
            virtual_hid_keyboard.keyboard_type_v2 = "ansi";
            complex_modifications.rules = [
              {
                description = "Caps lock: ctrl when held, escape when tapped";
                manipulators = [
                  {
                    type = "basic";
                    from = {
                      key_code = "caps_lock";
                      modifiers.optional = ["any"];
                    };
                    to = [
                      {
                        key_code = "left_control";
                        # Only emit ctrl once another key is pressed, so a
                        # bare tap can become escape.
                        lazy = true;
                      }
                    ];
                    to_if_alone = [{key_code = "escape";}];
                  }
                ];
              }
            ];
          }
        ];
      };
    };
}
