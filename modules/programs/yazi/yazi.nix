{
  # Yazi: a TUI file browser, also wired up as the xdg-desktop-portal file
  # chooser so app file pickers (browser uploads, "save as") use yazi.

  flake.modules.nixos.yazi = {pkgs, ...}: {
    programs.yazi.enable = true;

    environment.systemPackages = [
      pkgs.yaziPlugins.gvfs # mount devices to a VFS in yazi
    ];

    xdg.mime = {
      enable = true;
      defaultApplications."inode/directory" = "yazi.desktop";
    };

    # Route the FileChooser portal to termfilechooser. Set in both `common` and
    # `niri` because niri-portals.conf (from programs.niri) would otherwise
    # shadow the common route. Inert without xdg.portal.enable.
    xdg.portal.extraPortals = [pkgs.xdg-desktop-portal-termfilechooser];
    xdg.portal.config = {
      common."org.freedesktop.impl.portal.FileChooser" = ["termfilechooser"];
      niri."org.freedesktop.impl.portal.FileChooser" = ["termfilechooser"];
    };
  };

  flake.modules.homeManager.yazi = {
    pkgs,
    lib,
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
    # Linux-only: portals don't exist on Darwin and ghostty has no Darwin build.
    lib.mkIf pkgs.stdenv.isLinux {
      xdg.configFile."xdg-desktop-portal-termfilechooser/config".text = ''
        [filechooser]
        cmd=${lib.getExe wrapper}
        default_dir=$HOME
        open_mode=suggested
        save_mode=suggested
      '';
    };
}
