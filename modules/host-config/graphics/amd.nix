{
  flake.modules.nixos.graphics-amd = {
    config,
    lib,
    ...
  }:
    lib.mkIf (config.hostConstants.graphicsType == "amd") {
      # No general AMD config needed: per-program GPU-compute settings live in
      # each program's feature (modules/programs/blender, davinci-resolve).
    };
}
