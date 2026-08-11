{inputs, ...}: {
  # Jake's personal MacBook ("aspen", formerly "Jakes-MacBook-Air").
  flake.hosts.aspen = {
    class = "darwin";
    system = "aarch64-darwin";
    users = ["jakeneau"];
    globalPrograms = ["ghostty" "firefox" "fastfetch" "gh"];
    baselines = ["role-desktop" "mac-app-util"];
  };

  flake.modules.darwin.aspen = {...}: {
    imports = [
      inputs.self.modules.darwin.role-desktop
      inputs.self.modules.generic.cli
      inputs.self.modules.generic.numtide-cache
    ];

    hostConstants.hostName = "aspen";
    hostConstants.monitorResolution = {
      horizontal = 2560;
      vertical = 1664;
    };

    # Host facts features branch on (e.g. fastfetch's Power box).
    hostConstants.isLaptop = true;
    hostConstants.graphicsType = "apple";

    # repo write without sudo; the group itself comes from modules/host-config/config-group
    users.groups.config.members = ["jakeneau"];
  };
}
