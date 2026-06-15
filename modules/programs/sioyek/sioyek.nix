{
  # Sioyek: a keyboard-driven PDF reader built for papers and textbooks
  # (vim-flavored keybindings, marks/bookmarks, smart citation jumping).
  #
  # Cross-platform [nd]: nixpkgs builds sioyek on both Linux and macOS, so a
  # single home-manager aspect installs it everywhere. home-manager now ships a
  # native `programs.sioyek` module, so the package, key bindings and prefs are
  # all declared here. Setting sioyek as the default PDF reader differs per OS:
  # Linux uses XDG mimeapps; macOS has no declarative LaunchServices option, so
  # `duti` sets the handler from an activation script.

  flake.modules.homeManager.sioyek = {
    pkgs,
    lib,
    ...
  }:
    lib.mkMerge [
      {
        programs.sioyek = {
          enable = true;
          # Page up/down rebound to vim-style Ctrl+K / Ctrl+J. These are added
          # on top of the built-in <pageup>/<pagedown> keys (sioyek has no clean
          # per-key unbind), so the original keys keep working too.
          bindings = {
            "screen_down" = "<C-j>";
            "screen_up" = "<C-k>";
          };
        };
      }

      # Linux: register sioyek as the default PDF handler via XDG mimeapps.
      (lib.mkIf pkgs.stdenv.isLinux {
        xdg.mimeApps = {
          enable = true;
          defaultApplications."application/pdf" = "sioyek.desktop";
        };
      })

      # macOS: LaunchServices has no declarative option, so set the default PDF
      # handler to sioyek's bundle id with duti on each activation (idempotent).
      (lib.mkIf pkgs.stdenv.isDarwin {
        home.packages = [pkgs.duti];
        home.activation.sioyekDefaultPdf =
          lib.hm.dag.entryAfter ["writeBoundary"] ''
            $DRY_RUN_CMD ${lib.getExe pkgs.duti} -s info.sioyek.sioyek com.adobe.pdf all || true
          '';
      })
    ];
}
