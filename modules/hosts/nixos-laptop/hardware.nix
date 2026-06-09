{
  # ┌─────────────────────────────────────────────────────────────────────┐
  # │ PLACEHOLDER hardware config for the NixOS laptop.                     │
  # │ These device UUIDs are FAKE. The config evaluates and builds, but it │
  # │ will NOT boot until you replace this with the real output of         │
  # │ `nixos-generate-config` run on the actual laptop.                    │
  # └─────────────────────────────────────────────────────────────────────┘
  flake.modules.nixos.nixos-laptop = {
    config,
    lib,
    modulesPath,
    ...
  }: {
    imports = [(modulesPath + "/installer/scan/not-detected.nix")];

    boot.initrd.availableKernelModules = ["xhci_pci" "nvme" "usbhid" "sd_mod"];
    boot.initrd.kernelModules = [];
    boot.kernelModules = ["kvm-intel"]; # adjust to your CPU (kvm-amd/kvm-intel)
    boot.extraModulePackages = [];

    # REPLACE: real root / boot / swap from nixos-generate-config.
    fileSystems."/" = {
      device = "/dev/disk/by-uuid/00000000-0000-0000-0000-000000000000";
      fsType = "ext4";
    };

    fileSystems."/boot" = {
      device = "/dev/disk/by-uuid/0000-0000";
      fsType = "vfat";
      options = ["fmask=0077" "dmask=0077"];
    };

    swapDevices = [];

    networking.useDHCP = lib.mkDefault true;
    nixpkgs.hostPlatform = "x86_64-linux";
  };
}
