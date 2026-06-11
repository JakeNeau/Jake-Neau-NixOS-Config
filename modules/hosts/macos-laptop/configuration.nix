{inputs, ...}: {
  # Jake's personal MacBook ("macos-laptop", formerly "Jakes-MacBook-Air").
  flake.modules.darwin.macos-laptop = {pkgs, ...}: {
    imports =
      (with inputs.self.modules.darwin; [
        system-desktop
        fastfetch
        jakeneau
      ])
      ++ [inputs.self.modules.generic.cli];

    networking.hostName = "macos-laptop";

    # Host facts features branch on (e.g. fastfetch's Power box).
    systemConstants.isLaptop = true;

    environment.systemPackages = [
      pkgs.librewolf
      pkgs.claude-code
    ];
  };
}
