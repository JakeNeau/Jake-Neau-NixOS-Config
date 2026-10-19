{ inputs, lib, ... }:
{
  flake-file.inputs.home-assistant-icon = {
    url = "file+https://brands.home-assistant.io/_/homeassistant/icon.png";
    flake = false;
  };

  flake.programs.home-assistant = {
    install.linux = [ "home" ];
    install.macos = [ "cask" ];
    hasEnableOption = false;

    packages =
      pkgs:
      let
        icon = "${inputs.home-assistant-icon}";
        launcher = pkgs.writeShellApplication {
          name = "home-assistant";
          text = ''
            exec ${lib.getExe pkgs.ungoogled-chromium} \
              --app=https://ha.jakeneau.com \
              --class=home-assistant \
              "$@"
          '';
        };
        desktopItem = pkgs.makeDesktopItem {
          name = "home-assistant";
          desktopName = "Home Assistant";
          genericName = "Home Automation";
          comment = "Control Home Assistant";
          exec = lib.getExe launcher;
          inherit icon;
          categories = [ "Network" ];
          keywords = [
            "home"
            "automation"
          ];
          startupWMClass = "home-assistant";
        };
      in
      lib.optionals pkgs.stdenv.hostPlatform.isLinux [
        (pkgs.symlinkJoin {
          name = "home-assistant-control";
          paths = [
            launcher
            desktopItem
          ];
        })
      ];

    config = { lib, ... }: {
      options.programs.home-assistant.enableMcpIntegration = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether Pi connects to the Home Assistant MCP server.";
      };
    };
  };
}
