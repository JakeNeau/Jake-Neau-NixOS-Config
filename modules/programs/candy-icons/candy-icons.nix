{
  # candy-icons: a gradient vector icon theme.
  flake.modules.homeManager.candy-icons = {pkgs, ...}: {
    gtk.iconTheme = {
      package = pkgs.candy-icons;
      name = "candy-icons";
    };
  };
}
