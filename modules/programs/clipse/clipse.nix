{
  # clipse: a clipboard manager with a TUI history picker.
  flake.modules.homeManager.clipse = {
    services.clipse = {
      enable = true;
      imageDisplay = {
        type = "kitty";
        scaleX = 9;
        scaleY = 9;
      };
    };
  };
}
