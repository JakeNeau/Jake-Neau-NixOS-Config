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
    hardware.i2c.enable = true;
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
        if ! timeout 5s ${lib.escapeShellArg (lib.getExe backend)} "$action"; then
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
          : "$action"
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
    };

    config.home.packages = [monitorPower];
  };
}
