{
  # wl-clipboard: command-line copy/paste (wl-copy / wl-paste) for wayland.
  flake.modules.homeManager.wl-clipboard = {pkgs, ...}: {
    home.packages = [pkgs.wl-clipboard];
  };
}
