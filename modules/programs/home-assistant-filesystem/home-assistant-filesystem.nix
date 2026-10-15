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
      system.fsPackages = [
        pkgs.bindfs
        pkgs.cifs-utils
      ];

      fileSystems = {
        "/run/home-assistant-config" = {
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
            "credentials=${config.sops.secrets.homeAssistantSambaCredentials.path}"
            "uid=0"
            "gid=0"
            "file_mode=0600"
            "dir_mode=0700"
          ];
        };

        "/mnt/home-assistant-www" = {
          device = "/run/home-assistant-config/www";
          fsType = "fuse.bindfs";
          depends = [ "/run/home-assistant-config/www" ];
          options = [
            "nofail"
            "noauto"
            "x-systemd.automount"
            "x-systemd.idle-timeout=60"
            "force-user=jakeneau"
            "force-group=users"
            "create-for-user=0"
            "create-for-group=0"
            "perms=u=rwX:g=:o="
          ];
        };
      };
    };
}
