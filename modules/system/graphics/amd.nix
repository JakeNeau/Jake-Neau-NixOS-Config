{
  flake.modules.nixos.graphics-amd = {
    config,
    lib,
    pkgs,
    ...
  }:
    lib.mkIf (config.systemConstants.graphicsType == "amd") {
      hardware.graphics.extraPackages = with pkgs; [
        rocmPackages.clr.icd # OpenCL runtime via the ROCm ICD
        mesa.opencl
      ];
      nixpkgs.config.rocmSupport = true;
      # Rusticl (Mesa's OpenCL) is opt-in per driver.
      environment.variables.RUSTICL_ENABLE = "radeonsi";
    };
}
