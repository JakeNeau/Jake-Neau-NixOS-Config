{
  # Hide tools that ship a .desktop entry but shouldn't appear in the app launcher
  # (Qt config shims, the bare terminals/editor, the NixOS manual) by shadowing each
  # with a NoDisplay=true entry.
  flake.modules.homeManager.hidden-desktop-entries = {
    home.file = {
      ".local/share/applications/qt5ct.desktop".text = "[Desktop Entry]\nNoDisplay=true";
      ".local/share/applications/qt6ct.desktop".text = "[Desktop Entry]\nNoDisplay=true";
      ".local/share/applications/kvantummanager.desktop".text = "[Desktop Entry]\nNoDisplay=true";
      ".local/share/applications/xterm.desktop".text = "[Desktop Entry]\nNoDisplay=true";
      ".local/share/applications/nvim.desktop".text = "[Desktop Entry]\nNoDisplay=true";
      ".local/share/applications/nixos-manual.desktop".text = "[Desktop Entry]\nNoDisplay=true";
    };
  };
}
