{
  flake.modules.nixos.graphics-amd = {
    config,
    lib,
    ...
  }:
    lib.mkIf (config.hostConstants.graphicsType == "amd") {
      hardware.amdgpu.initrd.enable = true;
    };
}
