{
  flake.modules.nixos.blender = {
    config,
    lib,
    pkgs,
    ...
  }: {
    environment.systemPackages = [pkgs.blender]; # 3D modeling / art
    # AMD only: build Blender with HIP for Cycles GPU rendering (its only AMD path).
    nixpkgs.config.rocmSupport = lib.mkIf (config.hostConstants.graphicsType == "amd") true;
  };
}
