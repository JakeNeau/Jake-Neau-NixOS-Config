{
  flake.modules.darwin.graphics-apple = {
    config,
    lib,
    ...
  }:
    lib.mkIf (config.systemConstants.graphicsType == "apple") {
      # macOS drives its own GPU; no-op vendor module to complete the set.
    };
}
