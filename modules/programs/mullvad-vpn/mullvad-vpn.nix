{
  # Mullvad VPN: a root daemon plus a GUI. Each platform's systemConfig
  # installs it and publishes how to exclude a program from it, which the
  # excludeFromVpn machinery reads (see docs/explanation/mullvad-split-tunneling.md).
  flake.programs.mullvad-vpn = {
    # home-manager's settings would make the app's own preferences read-only
    shared.config.programs.mullvad-vpn.enable = true;

    linux = {
      install = [ "custom" ];
      systemConfig =
        { config, lib, ... }:
        {
          services.mullvad-vpn = {
            enable = true;
            gui.enable = true;
            # match upstream's distro packages, which block traffic until the daemon starts
            enableEarlyBootBlocking = true;
          };

          # Moves the wrapper's shell, and so the program it execs, into the
          # exclusion cgroup. A stopped daemon must not stop the launch.
          hostConstants.vpn.excludeCommands = [
            "${lib.getExe' config.services.mullvad-vpn.package "mullvad"} split-tunnel add $$ >/dev/null 2>&1 || true"
          ];
        };
    };

    macos = {
      install = [ "cask" ];
      systemConfig =
        { pkgs, ... }:
        {
          # The daemon matches exact executable paths. The state file records
          # what this writer added, so entries added elsewhere stay.
          hostConstants.vpn.syncExcludedApps = [
            "${pkgs.writeShellScript "mullvad-sync-excluded-apps" ''
              set -eu
              state=$1
              shift
              # the cask's installer links the CLI here
              mullvad=/usr/local/bin/mullvad
              "$mullvad" status >/dev/null
              mkdir -p "$(dirname "$state")"
              touch "$state"
              # an interrupted run must still have every path it may have added on record
              { cat "$state"; [ $# -eq 0 ] || printf '%s\n' "$@"; } | sort -u >"$state.new"
              mv "$state.new" "$state"
              while IFS= read -r old; do
                for path in "$@"; do
                  [ "$path" = "$old" ] && continue 2
                done
                "$mullvad" split-tunnel app remove "$old" >/dev/null
              done <"$state"
              for path in "$@"; do
                "$mullvad" split-tunnel app add "$path" >/dev/null
              done
              if [ $# -gt 0 ]; then
                printf '%s\n' "$@" >"$state"
                "$mullvad" split-tunnel set on >/dev/null
              else
                : >"$state"
              fi
            ''}"
          ];
        };
    };
  };
}
