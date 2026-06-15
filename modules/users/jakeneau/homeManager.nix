{inputs, ...}: {
  # Jake's home environment. Cross-platform core (git, jujutsu, editor, CLI);
  # the Linux/wayland desktop programs are gated to Linux so the same config
  # also evaluates on macOS.
  flake.modules.homeManager.jakeneau = {
    config,
    pkgs,
    lib,
    ...
  }: {
    imports = with inputs.self.modules.homeManager; [
      system-desktop
      librewolf
    ];

    config = lib.mkMerge [
      # --------------------
      # Cross-platform core
      # --------------------
      {
        programs.git = {
          enable = true;
          settings.user = {
            name = "Jake Neau";
            email = "jakeneau@proton.me";
          };
        };

        programs.jujutsu = {
          enable = true;
          settings.user = {
            name = "Jake Neau";
            email = "jakeneau@proton.me";
          };
        };
      }

      # ----------------------
      # Linux/wayland desktop
      # ----------------------
      (lib.mkIf pkgs.stdenv.isLinux {
        # ----------
        # GTK theme
        # ----------
        # Themes for gtk (most apps)
        gtk = {
          iconTheme = {
            package = pkgs.candy-icons;
            name = "candy-icons";
          };
        };

        # ----------
        # Clipboard
        # ----------
        services.clipse = {
          enable = true;
          imageDisplay = {
            type = "kitty";
            scaleX = 9;
            scaleY = 9;
          };
        };

        # ---------------
        # Fuzzel launcher
        # ---------------
        programs.fuzzel = {
          enable = true;
          settings = {
            main = {
              terminal = "${pkgs.ghostty}/bin/ghostty -e";
              font = lib.mkForce "monospace:size=24";
              line-height = 60;
              lines = 12;
              match-mode = "fzf";
              tabs = 4;
              use-bold = "true";
              width = 32;
              icon-theme = config.gtk.iconTheme.name;
            };
          };
        };

        # Create files to hide unused fuzzel programs
        home.file = {
          ".local/share/applications/qt5ct.desktop".text = "[Desktop Entry]\nNoDisplay=true";
          ".local/share/applications/qt6ct.desktop".text = "[Desktop Entry]\nNoDisplay=true";
          ".local/share/applications/kvantummanager.desktop".text = "[Desktop Entry]\nNoDisplay=true";
          ".local/share/applications/xterm.desktop".text = "[Desktop Entry]\nNoDisplay=true";
          ".local/share/applications/nvim.desktop".text = "[Desktop Entry]\nNoDisplay=true";
          ".local/share/applications/nixos-manual.desktop".text = "[Desktop Entry]\nNoDisplay=true";
        };
      })
    ];
  };
}
