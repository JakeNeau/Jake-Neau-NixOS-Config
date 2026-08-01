{
  flake.modules.nixos.monitor-power = {
    hardware.i2c.enable = true;
  };

  flake.modules.homeManager.monitor-power = {pkgs, ...}: let
    monitorPower = pkgs.writeShellApplication {
      name = "monitor-power";
      runtimeInputs = with pkgs; [
        coreutils
        ddcutil
        gawk
        niri
      ];
      text = ''
        if (( $# != 1 )); then
          echo "usage: monitor-power {on|off}" >&2
          exit 2
        fi

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

        case "$1" in
          on)
            niri msg action power-on-monitors || true
            sleep 1
            set_ddc_power 01
            ;;

          off)
            set_ddc_power 05
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
    home.packages = [monitorPower];
  };
}
