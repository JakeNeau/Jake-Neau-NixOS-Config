{
  # fuzzel: a fast application launcher for wayland.
  flake.modules.homeManager.fuzzel = {
    config,
    pkgs,
    lib,
    ...
  }: {
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
          # Match the launcher icons to the active GTK icon theme.
          icon-theme = config.gtk.iconTheme.name;
        };
      };
    };
  };
}
