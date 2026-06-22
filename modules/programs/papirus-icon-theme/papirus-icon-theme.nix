{
  # papirus-icon-theme: fallback icon set for apps not covered by the main theme.
  flake.modules.homeManager.papirus-icon-theme = {pkgs, ...}: {
    home.packages = [pkgs.papirus-icon-theme];
  };
}
