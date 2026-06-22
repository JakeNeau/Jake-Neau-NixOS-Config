{
  # udiskie: automatic mounting of removable media for the desktop.
  flake.modules.homeManager.udiskie = {pkgs, ...}: {
    home.packages = [pkgs.udiskie];
  };
}
