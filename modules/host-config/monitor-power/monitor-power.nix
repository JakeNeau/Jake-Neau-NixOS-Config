{lib, ...}: {
  flake.lib.monitorPower.samsungTizen = {
    pkgs,
    name,
    hostname,
    tokenFile,
    remoteName,
  }: let
    python = pkgs.python3.withPackages (pythonPackages: [
      pythonPackages.samsungtvws
      pythonPackages.yarl
    ]);
  in
    pkgs.runCommand name {
      nativeBuildInputs = [pkgs.makeWrapper];
      meta.mainProgram = name;
    } ''
      SAMSUNG_TIZEN_POWER_MODULE=${./samsung_tizen_power.py} \
        ${python}/bin/python \
        ${./samsung_tizen_power_test.py}

      mkdir -p $out/bin
      makeWrapper \
        ${python}/bin/python \
        $out/bin/${name} \
        --add-flags ${./samsung_tizen_power.py} \
        --add-flags ${lib.escapeShellArg "--hostname=${hostname}"} \
        --add-flags ${lib.escapeShellArg "--token-file=${tokenFile}"} \
        --add-flags ${lib.escapeShellArg "--remote-name=${remoteName}"}
    '';

  flake.modules.nixos.monitor-power = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.monitorPower;
    reprobeCommands =
      lib.concatMapStringsSep "\n" (connector: ''
        for statusFile in /sys/class/drm/card*-${connector}/status; do
          [[ -e "$statusFile" ]] || continue
          if [[ "$(< "$statusFile")" == disconnected ]]; then
            printf 'detect\n' > "$statusFile"
          fi
        done
      '')
      cfg.reprobeConnectors;
    sleepTargets = [
      "suspend.target"
      "hibernate.target"
      "suspend-then-hibernate.target"
    ];
  in {
    options.monitorPower = {
      reprobeConnectors = lib.mkOption {
        type = lib.types.listOf (lib.types.strMatching "[A-Za-z0-9-]+");
        default = [];
        description = "DRM connectors to force-reprobe while disconnected.";
      };
      resumeUsers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Users whose monitor-power resume service starts after system sleep.";
      };
    };

    config = lib.mkMerge [
      {hardware.i2c.enable = true;}
      (lib.mkIf (cfg.reprobeConnectors != []) {
        systemd.services.monitor-power-reprobe = {
          description = "Reprobe disconnected DRM monitor connectors";
          wantedBy = ["multi-user.target"];
          path = [pkgs.coreutils];
          serviceConfig = {
            Restart = "on-failure";
            RestartSec = 5;
          };
          script = ''
            while true; do
              ${reprobeCommands}
              sleep 5
            done
          '';
        };
      })
      (lib.mkIf (cfg.resumeUsers != []) {
        systemd.services.monitor-power-resume-users = {
          description = "Restore user monitors after system sleep";
          wantedBy = sleepTargets;
          after = sleepTargets;
          path = [pkgs.systemd];
          serviceConfig.Type = "oneshot";
          script =
            lib.concatMapStringsSep "\n" (user: ''
              if ! systemctl --user --machine=${lib.escapeShellArg "${user}@"} start monitor-power-resume.service; then
                echo "monitor-power: failed to start the resume service for ${lib.escapeShellArg user}" >&2
              fi
            '')
            cfg.resumeUsers;
        };
      })
    ];
  };

  flake.modules.homeManager.monitor-power = {
    config,
    lib,
    pkgs,
    ...
  }: let
    cfg = config.monitorPower;
    backendCommands = lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: backend: ''
        if ! timeout "$backendTimeout" ${lib.escapeShellArg (lib.getExe backend)} "$action"; then
          echo "monitor-power: backend ${lib.escapeShellArg name} failed" >&2
        fi
      '')
      cfg.backends
    );
    monitorPower = pkgs.writeShellApplication {
      name = "monitor-power";
      runtimeInputs = with pkgs;
        [
          coreutils
          gawk
          niri
        ]
        ++ lib.optionals cfg.ddc.enable [ddcutil];
      text = ''
        if (( $# != 1 )); then
          echo "usage: monitor-power {on|off}" >&2
          exit 2
        fi

        ${lib.optionalString cfg.ddc.enable ''
          set_ddc_power() {
            local value="$1"
            local buses=()

            mapfile -t buses < <(
              timeout 5s ddcutil detect --brief 2>/dev/null |
                awk '
                  /^Display [[:digit:]]+$/ {
                    valid = 1
                    next
                  }

                  /^Invalid display$/ {
                    valid = 0
                    next
                  }

                  valid && /I2C bus:/ {
                    sub(".*/i2c-", "", $3)
                    print $3
                    valid = 0
                  }
                '
            )

            for bus in "''${buses[@]}"; do
              if ! timeout 3s ddcutil \
                --bus "$bus" \
                --noverify \
                setvcp D6 "$value"
              then
                echo "monitor-power: DDC power control failed on I2C bus $bus" >&2
              fi
            done
          }
        ''}

        run_backends() {
          local action="$1"
          local backendTimeout=5s

          if [[ "$action" == on ]]; then
            backendTimeout=35s
          fi

          : "$backendTimeout"
          ${backendCommands}
        }

        case "$1" in
          on)
            niri msg action power-on-monitors || true
            run_backends on
            sleep 1
            ${lib.optionalString cfg.ddc.enable "set_ddc_power 01"}
            ;;

          off)
            ${lib.optionalString cfg.ddc.enable "set_ddc_power 05"}
            run_backends off
            niri msg action power-off-monitors || true
            ;;

          *)
            echo "usage: monitor-power {on|off}" >&2
            exit 2
            ;;
        esac
      '';
    };
    sleepTransitionCommand =
      if cfg.resumeAfterSleep.enable
      then ''exec systemctl "$1"''
      else ''
        systemctl "$1"
        ${lib.getExe monitorPower} on
      '';
    screenOffCommand =
      if cfg.screenOff.wakeOnInput.enable
      then ''
        systemctl --user start swayidle.service
        # Let the shortcut keys release before swayidle watches for resume input.
        sleep 0.25
        systemctl --user kill --signal=SIGUSR1 swayidle.service
      ''
      else ''exec niri msg action power-off-monitors'';
    monitorPowerScreenOff = pkgs.writeShellApplication {
      name = "monitor-power-screen-off";
      runtimeInputs = [pkgs.coreutils pkgs.niri pkgs.systemd];
      text = screenOffCommand;
    };
    monitorPowerTransition = pkgs.writeShellApplication {
      name = "monitor-power-transition";
      runtimeInputs = [pkgs.coreutils pkgs.systemd];
      text = ''
        if (( $# != 1 )); then
          echo "usage: monitor-power-transition {suspend-then-hibernate|hibernate|reboot|poweroff}" >&2
          exit 2
        fi

        case "$1" in
          suspend-then-hibernate|hibernate)
            ${lib.getExe monitorPower} off
            sleep 1
            ${sleepTransitionCommand}
            ;;

          reboot|poweroff)
            ${lib.getExe monitorPower} off
            sleep 1
            exec systemctl "$1"
            ;;

          *)
            echo "usage: monitor-power-transition {suspend-then-hibernate|hibernate|reboot|poweroff}" >&2
            exit 2
            ;;
        esac
      '';
    };
  in {
    options.monitorPower = {
      ddc.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether monitor-power controls displays through DDC/CI.";
      };
      backends = lib.mkOption {
        type = lib.types.attrsOf lib.types.package;
        default = {};
        description = "Additional monitor-power backend packages keyed by device name.";
      };
      resumeAfterSleep.enable = lib.mkEnableOption "monitor restoration after system sleep";
      screenOff.wakeOnInput.enable = lib.mkEnableOption "firmware monitor wake on input after manual screen-off";
    };

    config = lib.mkMerge [
      {home.packages = [monitorPower monitorPowerScreenOff monitorPowerTransition];}
      (lib.mkIf cfg.resumeAfterSleep.enable {
        systemd.user.services.monitor-power-resume = {
          Unit.Description = "Restore monitors after system sleep";
          Service = {
            Type = "oneshot";
            ExecStart = "${lib.getExe monitorPower} on";
            TimeoutStartSec = 60;
          };
        };
      })
      (lib.mkIf cfg.screenOff.wakeOnInput.enable {
        services.swayidle = {
          enable = true;
          extraArgs = ["-w"];
          timeouts = [
            {
              timeout = 2147483647;
              command = "${lib.getExe monitorPower} off";
              resumeCommand = "${lib.getExe monitorPower} on";
            }
          ];
        };
      })
    ];
  };
}
