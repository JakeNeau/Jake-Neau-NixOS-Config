{
  # Steam bypasses every VPN on the host, so its game traffic and downloads
  # use the home connection. Redwood keeps its other programs.steam settings.
  flake.programs.steam = {
    linux = {
      install = [ "custom" ];
      systemConfig.programs.steam.enable = true;
    };
    macos.install = [ "cask" ];
    hasEnableOption = false;
    excludeFromVpn = true;
  };
}
