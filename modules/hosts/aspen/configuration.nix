{inputs, ...}: {
  # Jake's personal MacBook ("aspen", formerly "Jakes-MacBook-Air").
  flake.modules.darwin.aspen = {...}: {
    imports =
      (with inputs.self.modules.darwin; [
        system-desktop
        fastfetch
        jakeneau
      ])
      ++ [inputs.self.modules.generic.cli];

    systemConstants.hostName = "aspen";

    # Host facts features branch on (e.g. fastfetch's Power box).
    systemConstants.isLaptop = true;
    systemConstants.graphicsType = "apple";

    # repo write without sudo; the group itself comes from modules/system/config-group
    users.groups.config.members = ["jakeneau"];
  };
}
