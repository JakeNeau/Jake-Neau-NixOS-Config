{inputs, ...}: {
  # The NixOS laptop ("nixos-laptop"). Same desktop experience as the desktop
  # host, minus the desktop-only hardware (GPU/audio rig, openrgb, minecraft).
  flake.modules.nixos.nixos-laptop = {
    imports = with inputs.self.modules.nixos; [
      system-desktop
      fastfetch-laptop
      jakeneau
    ];

    networking.hostName = "nixos-laptop";

    # Simple UEFI bootloader (the desktop's themed GRUB is desktop-specific).
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    # The first system version installed.
    # REPLACE with the NixOS release this laptop is first installed with.
    system.stateVersion = "25.05";
  };
}
