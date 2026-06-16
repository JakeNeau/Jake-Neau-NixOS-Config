{inputs, ...}: {
  # The NixOS laptop ("spruce"). Same desktop experience as the desktop
  # host, minus the desktop-only hardware (GPU/audio rig, openrgb, minecraft).
  flake.modules.nixos.spruce = {
    imports = with inputs.self.modules.nixos; [
      system-desktop
      fastfetch
      local-ai
      jakeneau
    ];

    networking.hostName = "spruce";

    # Host facts features branch on (e.g. fastfetch's Power box).
    systemConstants.isLaptop = true;

    # Simple UEFI bootloader (the desktop's themed GRUB is desktop-specific).
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    # The first system version installed.
    # REPLACE with the NixOS release this laptop is first installed with.
    system.stateVersion = "25.05";
  };
}
