{
  # swaybg: sets the desktop wallpaper on wlroots/wayland compositors.
  flake.modules.homeManager.swaybg = {pkgs, ...}: {
    home.packages = [pkgs.swaybg];
  };
}
