{inputs, ...}: {
  # Jake's personal MacBook ("macos-laptop", formerly "Jakes-MacBook-Air").
  flake.modules.darwin.macos-laptop = {pkgs, ...}: {
    imports =
      (with inputs.self.modules.darwin; [
        system-desktop
        jakeneau
      ])
      ++ [inputs.self.modules.generic.cli];

    networking.hostName = "macos-laptop";

    environment.systemPackages = [
      pkgs.librewolf
      pkgs.claude-code
      pkgs.claude-agent-acp # ACP bridge for CodeCompanion's claude_code adapter
    ];
  };
}
