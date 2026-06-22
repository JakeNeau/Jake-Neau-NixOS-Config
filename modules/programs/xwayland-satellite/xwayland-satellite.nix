{
  # xwayland-satellite: rootless Xwayland support for wlroots compositors like niri.
  flake.modules.homeManager.xwayland-satellite = {pkgs, ...}: {
    home.packages = [pkgs.xwayland-satellite];
  };
}
