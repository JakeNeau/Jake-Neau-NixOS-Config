{inputs, ...}: {
  # Jake's personal MacBook ("aspen", formerly "Jakes-MacBook-Air").
  flake.modules.darwin.aspen = {...}: {
    imports =
      (with inputs.self.modules.darwin; [
        role-desktop
        fastfetch
        jakeneau
      ])
      ++ [inputs.self.modules.generic.cli];

    hostConstants.hostName = "aspen";

    # Host facts features branch on (e.g. fastfetch's Power box).
    hostConstants.isLaptop = true;
    hostConstants.graphicsType = "apple";

    # repo write without sudo; the group itself comes from modules/host-config/config-group
    users.groups.config.members = ["jakeneau"];
  };
}
