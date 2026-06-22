{
  # wl-clip-persist: keeps clipboard contents alive after the source window closes.
  flake.modules.homeManager.wl-clip-persist = {pkgs, ...}: {
    home.packages = [pkgs.wl-clip-persist];
  };
}
