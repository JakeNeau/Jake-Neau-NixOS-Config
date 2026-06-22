{
  flake.modules.nixos.graphics-intel = {
    config,
    lib,
    pkgs,
    ...
  }:
    lib.mkIf (config.systemConstants.graphicsType == "intel") {
      hardware.graphics.extraPackages = [pkgs.intel-media-driver]; # VAAPI, Broadwell+ (iHD)
      environment.variables.LIBVA_DRIVER_NAME = "iHD";
    };
}
