{
  flake.modules.darwin.graphics-apple = {
    config,
    lib,
    ...
  }:
    lib.mkIf (config.hostConstants.graphicsType == "apple") {
      # macOS drives its own GPU; no-op vendor module to complete the set.
    };
}
