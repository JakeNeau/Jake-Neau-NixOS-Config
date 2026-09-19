{
  flake.modules.nixos.davinci-resolve = {
    config,
    lib,
    pkgs,
    ...
  }: let
    # Blackmagic replaced the 21.1 archive; remove when nixpkgs carries this hash.
    davinciResolveStudio = pkgs.davinci-resolve-studio.override {
      runCommandLocal = name: attrs: script:
        pkgs.runCommandLocal name (attrs
          // {outputHash = "sha256-P+zu8/OuFcDcIkwV3UMq0qg9U2JEGRkKDP+VLQesZjw=";})
        script;
    };
  in
    lib.mkMerge [
      {environment.systemPackages = [davinciResolveStudio];} # professional video editor
      # AMD only: Resolve's working OpenCL backend on AMD is Rusticl. mesa.opencl
      # provides it; RUSTICL_ENABLE opts radeonsi in — without it Resolve won't see the GPU.
      (lib.mkIf (config.hostConstants.graphicsType == "amd") {
        hardware.graphics.extraPackages = [pkgs.mesa.opencl];
        environment.variables.RUSTICL_ENABLE = "radeonsi";
      })
    ];
}
