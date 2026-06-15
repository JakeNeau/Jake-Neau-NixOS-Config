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

    networking.hostName = "aspen";

    # Host facts features branch on (e.g. fastfetch's Power box).
    systemConstants.isLaptop = true;
  };
}
