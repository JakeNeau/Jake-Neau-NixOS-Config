{inputs, ...}: {
  # Factory: stamp out the fastfetch greeting config from isLaptop.
  #
  #   (flake.factory.fastfetch false) => { nixos.fastfetch-desktop = …;
  #     darwin.fastfetch-desktop = …; homeManager.fastfetch-desktop = …; }
  #   (flake.factory.fastfetch true)  => the same, named fastfetch-laptop, with
  #     an extra boxed Power section (power adapter + battery) after Hardware.
  #
  # The config itself is pure home-manager; the nixos/darwin aspects only push
  # the matching homeManager aspect to every user on the host, so a host picks
  # its variant with a single import. Instantiated in modules/programs/fastfetch.

  config.flake.factory.fastfetch = isLaptop: let
    name =
      if isLaptop
      then "fastfetch-laptop"
      else "fastfetch-desktop";
    push-to-users = {
      home-manager.sharedModules = [inputs.self.modules.homeManager.${name}];
    };
  in {
    nixos.${name} = push-to-users;
    darwin.${name} = push-to-users;

    homeManager.${name} = {
      pkgs,
      lib,
      ...
    }: let
      # Filesystem birth time of /: GNU stat on Linux, BSD stat on macOS.
      birth-command =
        if pkgs.stdenv.isDarwin
        then "stat -f %B /"
        else "stat -c %W /";
    in {
      programs.fastfetch = {
        enable = true;
        settings = {
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
            separator = "  ";
          };
          modules =
            [
              "break"
              {
                type = "custom";
                format = "┌───────────────────────────────Hardware───────────────────────────────┐";
              }
              {
                type = "host";
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
                format = "└──────────────────────────────────────────────────────────────────────┘";
              }
            ]
            ++ [
              "break"
              {
                type = "custom";
                format = "┌───────────────────────────────Software───────────────────────────────┐";
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
                format = "└──────────────────────────────────────────────────────────────────────┘";
              }
            ]
            ++ lib.optionals isLaptop [
              "break"
              {
                type = "custom";
                format = "┌────────────────────────────────Power─────────────────────────────────┐";
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
                format = "└──────────────────────────────────────────────────────────────────────┘";
              }
            ]
            ++ [
              "break"
              {
                type = "custom";
                format = "┌─────────────────────────────────Time─────────────────────────────────┐";
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
                type = "custom";
                format = "└──────────────────────────────────────────────────────────────────────┘";
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
  };
}
