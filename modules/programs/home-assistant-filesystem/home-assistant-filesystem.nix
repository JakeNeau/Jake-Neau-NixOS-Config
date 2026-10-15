{
  lib,
  ...
}:
{
  flake.programs.home-assistant-filesystem = {
    install.linux = [ "home" ];
    hasEnableOption = false;
    packages = pkgs: [ pkgs.mcp-server-filesystem ];
    handWritten = [ "nixos" ];

    config =
      { config, ... }:
      {
        assertions = [
          {
            assertion =
              !config.programs.home-assistant-filesystem.enable
              || lib.attrByPath [ "programs" "home-assistant" "enable" ] false config;
            message = "home-assistant-filesystem requires programs.home-assistant.enable.";
          }
        ];
      };
  };

  flake.modules.nixos.home-assistant-filesystem =
    { config, pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.cifs-utils ];

      fileSystems."/mnt/home-assistant-www" = {
        device = "//192.168.69.168/config";
        fsType = "cifs";
        options = [
          "_netdev"
          "nofail"
          "noauto"
          "x-systemd.automount"
          "x-systemd.idle-timeout=60"
          "x-systemd.mount-timeout=10s"
          "vers=3.1.1"
          "prefixpath=www"
          "credentials=${config.sops.secrets.homeAssistantSambaCredentials.path}"
          "uid=1001"
          "gid=100"
          "file_mode=0600"
          "dir_mode=0700"
        ];
      };
    };
}
