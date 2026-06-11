{
  # Caps lock as a dual-role key on every system: ctrl when held with another
  # key, escape when tapped alone.
  #
  # NixOS  [N]: kanata grabs the real keyboards at the evdev level, so the
  #             remap works in Wayland, X, and the console alike.
  # macOS  [d]: a Karabiner-Elements rule contributed to the karabiner
  #             feature (modules/programs/karabiner), which owns the app
  #             install and renders karabiner.json.

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

  flake.modules.homeManager.caps-dual-role = {
    karabiner.rules = [
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
  };
}
