{inputs, ...}: let
  # The config itself is pure home-manager; the system aspects only push the
  # homeManager aspect to every user on the host.
  push-to-users = {
    home-manager.sharedModules = [inputs.self.modules.homeManager.fastfetch];
  };
in {
  # ----------------------
  # System aspects (push)
  # ----------------------
  # Fastfetch: the system-info splash shown by the fish greeting on every
  # machine. One aspect for all hosts; hosts with systemConstants.isLaptop
  # (see modules/system/system-constants) get an extra boxed Power section
  # (battery + power adapter) between Software and Time.
  flake.modules.nixos.fastfetch = push-to-users;
  flake.modules.darwin.fastfetch = push-to-users;

  # -----------------------
  # Home-manager config
  # -----------------------
  flake.modules.homeManager.fastfetch = {
    config,
    pkgs,
    lib,
    osConfig ? {},
    ...
  }: let
    # Filesystem birth time of /: GNU stat on Linux, BSD stat on macOS.
    birth-command =
      if pkgs.stdenv.isDarwin
      then "stat -f %B /"
      else "stat -c %W /";
    # PC line value: bold hostname, em dash, then the hardware model. osConfig
    # is absent for standalone home-manager, so fall back to just the model.
    hostName =
      (
        if osConfig == null
        then {}
        else osConfig
      )
      .networking.hostName
      or "";
    pcFormat =
      if hostName == ""
      then "{name}"
      else "{#1}${hostName}{#} — {name}";
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
          ++ lib.optionals config.systemConstants.isLaptop [
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
}
