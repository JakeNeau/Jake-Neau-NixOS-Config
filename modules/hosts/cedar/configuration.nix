{inputs, ...}: {
  # The macOS work laptop ("cedar"). Only the jake.neau user
  # lives here.
  flake.modules.darwin.cedar = {...}: {
    imports = [
      inputs.self.modules.darwin.system-desktop
      inputs.self.modules.darwin.podman
      inputs.self.modules.darwin.fastfetch
      inputs.self.modules.darwin.local-ai
      inputs.self.modules.darwin."jake.neau"
      inputs.self.modules.generic.cli
    ];

    systemConstants.hostName = "cedar";

    # Host facts features branch on (e.g. fastfetch's Power box).
    systemConstants.isLaptop = true;
    systemConstants.graphicsType = "apple";

    # repo write without sudo; the group itself comes from modules/system/config-group
    users.groups.config.members = ["jake.neau"];

    # Kubernetes CLI tools — only on this work laptop for now.
    home-manager.users."jake.neau".imports = [inputs.self.modules.homeManager.kubernetes];

    # Host-specific homebrew casks (the homebrew machinery itself comes from
    # the homebrew feature via system-desktop).
    homebrew.casks = [
      "firefox"
    ];
  };
}
