{
  flake.modules.nixos.graphics-nvidia = {
    config,
    lib,
    ...
  }:
    lib.mkMerge [
      (lib.mkIf (config.hostConstants.graphicsType == "nvidia") {
        services.xserver.videoDrivers = ["nvidia"];
        hardware.nvidia = {
          modesetting.enable = true;
          nvidiaSettings = true;
          package = config.boot.kernelPackages.nvidiaPackages.stable;
          open = true; # open kernel module: correct for Turing+ (RTX 20-series and newer)
        };
      })
      # Laptop hybrid graphics: power saving + render offload. Set the bus IDs
      # on the host: hardware.nvidia.prime.{nvidiaBusId,intelBusId}.
      (lib.mkIf (config.hostConstants.graphicsType == "nvidia" && config.hostConstants.isLaptop) {
        hardware.nvidia.powerManagement.enable = true;
        hardware.nvidia.prime.offload = {
          enable = true;
          enableOffloadCmd = true;
        };
      })
    ];
}
