{
  # Yazi: a TUI file browser, installable per-user on both platforms; today
  # only the Linux hosts request it (their globalPrograms). On Linux it is
  # also wired up as the xdg-desktop-portal file chooser so app file
  # pickers (browser uploads, "save as") use yazi.

  flake.programs.yazi = {
    install.linux = ["home"];
    install.macos = ["home"];
    # The portal aspect below stays hand-written; suppress the nixos class
    # so no generated unit or tombstone collides with it.
    handWritten = ["nixos"];

    config = {
      pkgs,
      lib,
      config,
      ...
    }: let
      # Called by termfilechooser; writes the chosen path(s) to the output file.
      # Args: $1=multiple $2=directory $3=save $4=start-path $5=out-file.
      wrapper = pkgs.writeShellApplication {
        name = "yazi-termfilechooser-wrapper";
        runtimeInputs = [pkgs.ghostty pkgs.yazi pkgs.coreutils];
        text = ''
          directory="$2"
          save="$3"
          path="$4"
          out="$5"

          if [ "$save" = "1" ]; then
            set -- --chooser-file="$out" "$path"
          elif [ "$directory" = "1" ]; then
            set -- --chooser-file="$out" --cwd-file="$out.1" "$path"
          else
            set -- --chooser-file="$out" "$path"
          fi

          # Float via niri's ghostty.small-float window rule.
          ghostty --class=ghostty.small-float -e yazi "$@"

          if [ "$directory" = "1" ]; then
            if [ ! -s "$out" ] && [ -s "$out.1" ]; then
              cat "$out.1" >"$out"
            fi
            rm -f "$out.1"
          fi
        '';
      };
    in
      lib.mkMerge [
        {
          # Adopt Home Manager's 26.05 default explicitly so older home state
          # versions do not retain the legacy `yy` wrapper or warn about it.
          programs.yazi.shellWrapperName = "y";
        }

        # Linux-only: portals and mimeapps don't exist on Darwin and ghostty
        # has no Darwin build.
        (lib.mkIf pkgs.stdenv.isLinux {
          xdg.configFile."xdg-desktop-portal-termfilechooser/config".text = ''
            [filechooser]
            cmd=${lib.getExe wrapper}
            default_dir=$HOME
            open_mode=suggested
            save_mode=suggested
          '';

          # Claim the directory file-type default per-user, tied to the enable
          # switch so opting out of yazi also releases the default.
          xdg.mimeApps = lib.mkIf config.programs.yazi.enable {
            enable = true;
            defaultApplications."inode/directory" = "yazi.desktop";
          };
        })
      ];
  };

  # --------------------------------------------
  # NixOS module: FileChooser portal routing
  # --------------------------------------------
  # Inert without xdg.portal.enable. Documented edge: the route is
  # machine-global and assumes the wrapper above, so a user who opts out of
  # yazi flips their portal route back with a per-user override.
  flake.modules.nixos.yazi = {pkgs, ...}: {
    environment.systemPackages = [
      pkgs.yaziPlugins.gvfs # mount devices to a VFS in yazi
    ];

    xdg.portal.extraPortals = [pkgs.xdg-desktop-portal-termfilechooser];
    # both common and niri: niri-portals.conf (from programs.niri) would
    # otherwise shadow the common route
    xdg.portal.config = {
      common."org.freedesktop.impl.portal.FileChooser" = ["termfilechooser"];
      niri."org.freedesktop.impl.portal.FileChooser" = ["termfilechooser"];
    };
  };
}
