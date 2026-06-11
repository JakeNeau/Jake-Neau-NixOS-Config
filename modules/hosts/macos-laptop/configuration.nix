{inputs, ...}: {
  # Jake's personal MacBook ("macos-laptop", formerly "Jakes-MacBook-Air").
  flake.modules.darwin.macos-laptop = {pkgs, ...}: {
    imports =
      (with inputs.self.modules.darwin; [
        system-desktop
        fastfetch-laptop
        jakeneau
      ])
      ++ [inputs.self.modules.generic.cli];

    networking.hostName = "macos-laptop";

    environment.systemPackages = [
      pkgs.librewolf
      pkgs.claude-code
    ];
  };
}
