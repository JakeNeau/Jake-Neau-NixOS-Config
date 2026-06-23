{
  flake.modules.nixos.davinci-resolve = {
    config,
    lib,
    pkgs,
    ...
  }:
    lib.mkMerge [
      {environment.systemPackages = [pkgs.davinci-resolve-studio];} # professional video editor
      # AMD only: Resolve's working OpenCL backend on AMD is Rusticl. mesa.opencl
      # provides it; RUSTICL_ENABLE opts radeonsi in — without it Resolve won't see the GPU.
      (lib.mkIf (config.systemConstants.graphicsType == "amd") {
        hardware.graphics.extraPackages = [pkgs.mesa.opencl];
        environment.variables.RUSTICL_ENABLE = "radeonsi";
      })
    ];
}
