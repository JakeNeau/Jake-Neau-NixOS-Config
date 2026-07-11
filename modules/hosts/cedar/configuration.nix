{inputs, ...}: {
  # The macOS work laptop ("cedar"). Only the jake.neau user
  # lives here.
  flake.hosts.cedar = {
    class = "darwin";
    system = "aarch64-darwin";
    users = ["jake.neau"];
    globalPrograms = ["ghostty" "firefox" "fastfetch"];
    # The nix firefox package breaks against the org's SSO, so cedar takes
    # the cask; its users get the -config unit through the baseline.
    installOverrides.firefox = "cask";
    baselines = ["role-desktop" "mac-app-util"];
  };

  flake.modules.darwin.cedar = {...}: {
    imports = [
      inputs.self.modules.darwin.role-desktop
      inputs.self.modules.darwin.podman
      inputs.self.modules.generic.cli
      inputs.self.modules.generic.numtide-cache
    ];

    hostConstants.hostName = "cedar";

    # Host facts features branch on (e.g. fastfetch's Power box).
    hostConstants.isLaptop = true;
    hostConstants.graphicsType = "apple";

    # repo write without sudo; the group itself comes from modules/host-config/config-group
    users.groups.config.members = ["jake.neau"];
  };
}
