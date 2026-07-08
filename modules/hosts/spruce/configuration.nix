{inputs, ...}: {
  # The NixOS laptop ("spruce"). Same desktop experience as the desktop
  # host, minus the desktop-only hardware (GPU/audio rig, openrgb, minecraft).
  flake.hosts.spruce = {
    class = "nixos";
    system = "x86_64-linux";
    users = ["jakeneau"];
    globalPrograms = ["ghostty" "yazi" "fastfetch"];
    baselines = ["role-desktop" "niri-desktop" "stylix"];
  };

  flake.modules.nixos.spruce = {
    imports = [inputs.self.modules.nixos.role-desktop];

    hostConstants.hostName = "spruce";

    # Host facts features branch on (e.g. fastfetch's Power box).
    hostConstants.isLaptop = true;
    hostConstants.graphicsType = "nvidia";

    # Placeholder bus IDs — PRIME offload asserts they're set. Replace with the
    # real laptop's values.
    hardware.nvidia.prime = {
      nvidiaBusId = "PCI:1:0:0";
      intelBusId = "PCI:0:2:0";
    };

    # Simple UEFI bootloader (the desktop's themed GRUB is desktop-specific).
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    # The first system version installed.
    # REPLACE with the NixOS release this laptop is first installed with.
    system.stateVersion = "25.05";
  };
}
