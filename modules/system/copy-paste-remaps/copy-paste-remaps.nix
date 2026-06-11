{
  # Linux-style copy/paste muscle memory everywhere: ctrl+c / ctrl+v copy and
  # paste in GUI apps and in the terminal on both platforms.
  #
  # macOS   [d]: Karabiner swaps ctrl<->cmd for the standard shortcut keys in
  #              GUI apps, so ctrl+c copies and the displaced native ctrl
  #              functions stay reachable on cmd. Terminals are excluded so
  #              ctrl keeps its terminal meanings there.
  # Ghostty [d]: ctrl+c / ctrl+v are copy/paste and the interrupt byte moves
  #              to alt+c, identical on both platforms.
  # NixOS   [N]: the fzf.fish variables widget moves off ctrl-v to ctrl-alt-v,
  #              joining the plugin's own ctrl-alt-f/l/s/p family.
  #
  # Related: the nvf keymap alt+v -> visual block (modules/programs/nvf)
  # replaces vim's ctrl+v, which ghostty now consumes.

  flake.modules.homeManager.copy-paste-remaps = {
    pkgs,
    lib,
    ...
  }: let
    # The "standard" shortcut letters that swap ctrl<->cmd on macOS.
    swapKeys = ["a" "c" "f" "l" "n" "o" "p" "r" "s" "t" "v" "w" "x" "z"];
    # Terminals keep real ctrl (SIGINT and friends); ghostty gets its own
    # copy/paste binds below instead.
    notInTerminal = {
      type = "frontmost_application_unless";
      bundle_identifiers = [
        "^com\\.mitchellh\\.ghostty$"
        "^com\\.apple\\.Terminal$"
      ];
    };
  in {
    karabiner.rules = [
      {
        description = "Swap ctrl and cmd for standard shortcuts (outside terminals)";
        manipulators =
          lib.concatMap (key: [
            {
              type = "basic";
              from = {
                key_code = key;
                modifiers = {
                  mandatory = ["control"];
                  optional = ["any"];
                };
              };
              to = [
                {
                  key_code = key;
                  modifiers = ["left_command"];
                }
              ];
              conditions = [notInTerminal];
            }
            {
              type = "basic";
              from = {
                key_code = key;
                modifiers = {
                  mandatory = ["command"];
                  optional = ["any"];
                };
              };
              to = [
                {
                  key_code = key;
                  modifiers = ["left_control"];
                }
              ];
              conditions = [notInTerminal];
            }
          ])
          swapKeys;
      }
    ];

    programs.ghostty = {
      enable = true;
      # On macOS the app comes from the homebrew cask; only the config is
      # managed here.
      package = lib.mkIf pkgs.stdenv.isDarwin null;
      settings.keybind = [
        "ctrl+c=copy_to_clipboard"
        "ctrl+v=paste_from_clipboard"
        # The interrupt byte (0x03) moves here; fish and the tty react to the
        # byte, so cancel-line and SIGINT both follow it.
        "alt+c=text:\\x03"
      ];
    };
  };

  flake.modules.nixos.copy-paste-remaps = {
    # Runs after the plugin's vendor conf.d installed its defaults;
    # fzf_configure_bindings erases its previous bindings before re-installing.
    programs.fish.interactiveShellInit = ''
      # ctrl-v is paste now (ghostty); move the fzf variables widget to the
      # plugin's ctrl-alt family
      if functions --query fzf_configure_bindings
          fzf_configure_bindings --variables=ctrl-alt-v
      end

      # ghostty consumes alt-c for interrupt; re-home fish's capitalize-word
      bind ctrl-alt-c capitalize-word
    '';
  };
}
