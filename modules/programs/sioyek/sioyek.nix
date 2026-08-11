{
  # Sioyek: a keyboard-driven PDF reader built for papers and textbooks
  # (vim-flavored keybindings, marks/bookmarks, smart citation jumping).
  #
  # Cross-platform: nixpkgs builds sioyek on both Linux and macOS, so a
  # single home-manager aspect installs it everywhere. home-manager now ships a
  # native `programs.sioyek` module, so the package, key bindings and prefs are
  # all declared here. Setting sioyek as the default PDF reader differs per OS:
  # Linux uses XDG mimeapps; macOS has no declarative LaunchServices option, so
  # `duti` sets the handler from an activation script.

  flake.modules.homeManager.sioyek = {
    pkgs,
    lib,
    options,
    ...
  }:
    lib.mkMerge [
      {
        programs.sioyek = {
          enable = true;
          bindings = {
            # Override Sioyek's modal highlight binding with Vim-style movement.
            "move_right" = "h";
            "next_page" = "<C-j>";
            "previous_page" = "<C-k>";
          };
        };
      }

      (lib.optionalAttrs (options ? stylix.targets.sioyek.enable) {
        # Stylix enables Sioyek's image-distorting custom-color shader at startup.
        stylix.targets.sioyek.enable = false;
      })

      # Linux: register sioyek as the default PDF handler via XDG mimeapps.
      (lib.mkIf pkgs.stdenv.isLinux {
        xdg.mimeApps = {
          enable = true;
          defaultApplications."application/pdf" = "sioyek.desktop";
        };
      })

      # macOS: LaunchServices has no declarative option, so set the default PDF
      # handler to sioyek's bundle id with duti. `com.adobe.pdf` is a protected
      # content type, so any programmatic `duti -s` pops macOS's anti-hijacking
      # confirmation modal. Guard on the current handler so we only call duti
      # when it isn't already sioyek -- the modal then appears at most once (on
      # first switch), not on every rebuild.
      (lib.mkIf pkgs.stdenv.isDarwin {
        home.packages = [pkgs.duti];
        home.activation.sioyekDefaultPdf = lib.hm.dag.entryAfter ["writeBoundary"] ''
          if [ "$(${lib.getExe pkgs.duti} -d com.adobe.pdf 2>/dev/null)" != "info.sioyek.sioyek" ]; then
            $DRY_RUN_CMD ${lib.getExe pkgs.duti} -s info.sioyek.sioyek com.adobe.pdf all || true
          fi
        '';
      })
    ];
}
