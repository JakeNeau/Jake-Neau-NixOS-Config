{inputs, ...}: {
  # The macOS work laptop ("work-laptop"). Only the jake.neau user lives here.
  flake.modules.darwin.work-laptop = {pkgs, ...}: {
    imports = [
      inputs.self.modules.darwin.system-desktop
      inputs.self.modules.darwin."jake.neau"
    ];

    networking.hostName = "work-laptop";

    environment.systemPackages = [
      pkgs.claude-code
    ];
  };
}
