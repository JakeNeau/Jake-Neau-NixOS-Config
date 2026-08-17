let
  # ---------------------------
  # Shared home-manager config
  # ---------------------------
  # Hosts with hostConstants.isLaptop (see modules/host-config/host-constants)
  # get an extra boxed Power section (battery + power adapter) between
  # Software and Time. Let-bound rather than inline in the declaration so the
  # settings block below keeps its indentation — its key strings carry
  # nerd-font glyphs that must never be retyped.
  fastfetch-config = {
    config,
    pkgs,
    lib,
    ...
  }: let
    # Filesystem birth time of /: GNU stat on Linux, BSD stat on macOS.
    birth-command =
      if pkgs.stdenv.hostPlatform.isDarwin
      then "stat -f %B /"
      else "stat -c %W /";
    # PC line value: bold hostname, em dash, then the hardware model. The
    # hostname arrives via the baseline's hostConstants read-through.
    pcFormat = "{#1}${config.hostConstants.hostName}{#} — {name}";
  in {
    programs.fastfetch = {
      enable = true;
      settings = {
        # ----------------
        # Logo & display
        # ----------------
        logo = {
          source = "builtin";
          padding = {
            top = 5;
            left = 3;
          };
        };
        display = {
          size = {
            binaryPrefix = "si";
          };
          color = "blue";
          separator = " │ ";
        };
        # -----------------------------
        # Modules (ordered info boxes)
        # -----------------------------
        modules =
          # ----------
          # Hardware
          # ----------
          [
            "break"
            {
              type = "custom";
              format = "┌─────────────┬───────────────Hardware─────────────────────────────┐";
            }
            {
              type = "host";
              format = pcFormat;
              key = " PC         ";
              keyColor = "green";
            }
            {
              type = "cpu";
              key = "│ ├ CPU     ";
              keyColor = "green";
            }
            {
              type = "gpu";
              key = "│ ├ GPU     ";
              keyColor = "green";
            }
            {
              type = "memory";
              key = "│ ├ Memory  ";
              keyColor = "green";
            }
            {
              type = "disk";
              key = "└ └ Disk    ";
              keyColor = "green";
            }
            {
              type = "custom";
              format = "└─────────────┴────────────────────────────────────────────────────┘";
            }
          ]
          # ----------
          # Software
          # ----------
          ++ [
            "break"
            {
              type = "custom";
              format = "┌─────────────┬───────────────Software─────────────────────────────┐";
            }
            {
              type = "os";
              key = " OS         ";
              keyColor = "yellow";
            }
            {
              type = "kernel";
              key = "│ ├ Kernel  ";
              keyColor = "yellow";
            }
            {
              type = "bios";
              key = "│ ├ BIOS    ";
              keyColor = "yellow";
            }
            {
              type = "packages";
              key = "│ ├󰏖 Packages";
              keyColor = "yellow";
            }
            {
              type = "shell";
              key = "└ └ Shell   ";
              keyColor = "yellow";
            }
            "break"
            {
              type = "wm";
              key = " Compositor ";
              keyColor = "blue";
            }
            {
              type = "lm";
              key = "│ ├ LM      ";
              keyColor = "blue";
            }
            {
              type = "terminal";
              key = "└ └ Terminal";
              keyColor = "blue";
            }
            {
              type = "custom";
              format = "└─────────────┴────────────────────────────────────────────────────┘";
            }
          ]
          # ---------------------
          # Power (laptops only)
          # ---------------------
          ++ lib.optionals config.hostConstants.isLaptop [
            "break"
            {
              type = "custom";
              format = "┌─────────────┬────────────────Power───────────────────────────────┐";
            }
            {
              type = "battery";
              key = "󰁹 Battery    ";
              keyColor = "cyan";
            }
            {
              type = "poweradapter";
              key = "└ └󰚥 Adapter ";
              keyColor = "cyan";
            }
            {
              type = "custom";
              format = "└─────────────┴────────────────────────────────────────────────────┘";
            }
          ]
          # ------
          # Time
          # ------
          ++ [
            "break"
            {
              type = "custom";
              format = "┌─────────────┬─────────────────Time───────────────────────────────┐";
            }
            {
              type = "command";
              key = "OS Age       ";
              keyColor = "magenta";
              text = "birth_install=$(${birth-command}); current=$(date +%s); time_progression=$((current - birth_install)); days_difference=$((time_progression / 86400)); echo $days_difference days";
            }
            {
              type = "uptime";
              key = "Uptime       ";
              keyColor = "magenta";
            }
            {
              type = "datetime";
              key = "System Time  ";
              keyColor = "magenta";
            }
            {
              type = "command";
              key = "UTC          ";
              keyColor = "magenta";
              text = "date -u '+%Y-%m-%d %H:%M:%S'";
            }
            {
              type = "custom";
              format = "└─────────────┴────────────────────────────────────────────────────┘";
            }
            {
              type = "colors";
              paddingLeft = 2;
              symbol = "circle";
            }
          ];
      };
    };
  };
in {
  # Fastfetch: the system-info splash shells show as their greeting, so it
  # installs per-user on every machine.
  flake.programs.fastfetch = {
    install.linux = ["home"];
    install.macos = ["home"];
    config = fastfetch-config;
  };
}
