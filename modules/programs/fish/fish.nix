{
  # Fish: the default interactive shell on every machine.
  #
  # NixOS: fish is each user's login shell (set by modules/factory/user);
  #        interactive bash also hands off to fish so a stray bash session
  #        lands in the same place.
  # macOS: macOS owns the account's login shell (zsh), so instead of
  #        changing the account, interactive zsh execs into fish.
  # Both:  aliases, functions, and plugins live in home-manager; each
  #        function is its own autoloadable functions/<name>.fish file.
  #        The flake-management helpers (nc, nr/nrr) detect the platform
  #        themselves (/etc/nixos vs /etc/nix-darwin) and work everywhere;
  #        the power shortcuts (r/s) differ per platform. Functions that
  #        need a specific program (eza, fastfetch, nix-minecraft) are
  #        installed only where that program is configured.
  #
  # Related: ctrl-v/alt-c keybind fixups come from modules/system/copy-paste-remaps.

  # -------------------------
  # NixOS: login shell + bash
  # -------------------------
  flake.modules.nixos.fish = {pkgs, ...}: {
    # Registers fish in /etc/shells (required for it to be a login shell) and
    # wires vendor completions/config for fish plugin packages.
    programs.fish.enable = true;

    # If bash ever starts interactively, hand off to fish. Keeps bash as the
    # safe default for scripts and non-interactive shells.
    programs.bash = {
      enable = true;
      interactiveShellInit = ''
        if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]
        then
          shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
          exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
        fi
      '';
    };
  };

  # --------------------------
  # macOS: zsh execs into fish
  # --------------------------
  flake.modules.darwin.fish = {pkgs, ...}: {
    # Installs fish system-wide, registers it in /etc/shells, and sets up the
    # nix environment + vendor plugin loading for fish sessions.
    programs.fish.enable = true;

    # macOS owns the account's login shell (zsh), so rather than chsh-ing the
    # user, interactive zsh execs into fish. Mirrors the bash hand-off on
    # NixOS; running `zsh` from inside fish still gives a real zsh.
    programs.zsh.interactiveShellInit = ''
      if [[ "$(basename "$(/bin/ps -o comm= -p $PPID)")" != "fish" && -z "$ZSH_EXECUTION_STRING" ]]; then
        [[ -o login ]] && LOGIN_OPTION='--login' || LOGIN_OPTION=""
        exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
      fi
    '';
  };

  # ------------------------------------------------
  # Both: aliases, functions, plugins (home-manager)
  # ------------------------------------------------
  flake.modules.homeManager.fish = {
    pkgs,
    lib,
    config,
    osConfig ? {},
    ...
  }: let
    # Installs each named function as its own ~/.config/fish/functions file,
    # where fish autoloads it on first call.
    functionFiles = names:
      lib.listToAttrs (map (name: {
          name = "fish/functions/${name}.fish";
          value.source = ./functions/${name}.fish;
        })
        names);

    # The mc-* helpers wrap systemd units that only exist when the host runs
    # nix-minecraft. osConfig is the host's system configuration; it is absent
    # for standalone home-manager configurations, hence the fallbacks.
    hasMinecraft =
      (
        if osConfig == null
        then {}
        else osConfig
      ).services.minecraft-servers.enable
      or false;
  in
    lib.mkMerge [
      {
        # -------
        # Plugins
        # -------
        # Plugins are picked up from the user profile through fish's vendor
        # dirs (NIX_PROFILES) on both platforms.
        home.packages = with pkgs.fishPlugins; [
          colored-man-pages # More interesting man pages
          fish-bd # Go back directories with bd
          # fzf-fish is marked broken on darwin only because its test suite
          # cannot run there; the plugin is plain fish script and works fine,
          # so build it without tests.
          (
            if pkgs.stdenv.isDarwin
            then
              fzf-fish.overrideAttrs (old: {
                doCheck = false;
                meta = old.meta // {broken = false;};
              })
            else fzf-fish # Search for multiple things with fzf
          )
          grc # A generic colorizer
          pisces # Adds parentheses, quotes, etc. in pairs
          plugin-sudope # Add sudo to a command when you forgot
          puffer # Useful text expansions
          pure # Minimal and fast fish prompt
          sponge # Remove typos from terminal
          z # Jump to previous directories
        ];

        # -----------------------
        # Aliases & shell startup
        # -----------------------
        programs.fish = {
          enable = true;
          shellAliases = {
            # Git aliases
            ga = "git add";
            gc = "git commit -m";
            gp = "git push";

            # General Command Aliases
            ng = "sudo nix-collect-garbage --delete-old";
          };
          shellInit = ''
            # Clean up all failed commands from history after 20 entries
            set sponge_delay 20
          '';
        };

        # --------------------
        # Autoloaded functions
        # --------------------
        xdg.configFile = functionFiles [
          "g"
          "h"
          "nc"
          "npd"
          "npr"
          "npv"
          "nr"
          "nrr"
          "suu"
        ];
      }

      # --------------------------
      # Program-conditional extras
      # --------------------------
      # eza-backed listing commands, only where eza (programs/cli-tools) is
      # actually installed.
      (lib.mkIf config.programs.eza.enable {
        programs.fish.shellAliases.ls = "eza --icons --group-directories-first";
        xdg.configFile = functionFiles ["l"];
      })

      # The greeting is a fastfetch splash, so only override fish's default
      # greeting where fastfetch is installed.
      (lib.mkIf config.programs.fastfetch.enable {
        xdg.configFile = functionFiles ["fish_greeting"];
      })

      # Minecraft server controls, only on hosts that run nix-minecraft.
      (lib.mkIf hasMinecraft {
        xdg.configFile = functionFiles [
          "mc-list"
          "mc-logs"
          "mc-start"
          "mc-stop"
        ];
      })

      # ----------------------------
      # Per-platform power shortcuts
      # ----------------------------
      # systemd power shortcuts.
      (lib.mkIf pkgs.stdenv.isLinux {
        programs.fish.shellAliases = {
          # Power aliases
          r = "sudo systemctl reboot";
          s = "sudo systemctl poweroff";
        };
      })

      # macOS power shortcuts: shutdown(8) stands in for systemctl.
      (lib.mkIf pkgs.stdenv.isDarwin {
        programs.fish.shellAliases = {
          # Power aliases
          r = "sudo shutdown -r now";
          s = "sudo shutdown -h now";
        };
      })
    ];
}
