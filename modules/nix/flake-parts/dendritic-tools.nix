{inputs, ...}: {
  # Setup of the tooling that powers the dendritic pattern.
  #
  #   flake-parts  - compose the flake from small modules (https://flake.parts)
  #   flake-file   - generate flake.nix from module options (vic/flake-file)
  #   import-tree  - import every .nix under ./modules (vic/import-tree)

  flake-file.inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-file.url = "github:vic/flake-file";
    import-tree.url = "github:vic/import-tree";
  };

  imports = [
    inputs.flake-parts.flakeModules.modules
    inputs.flake-file.flakeModules.default
  ];

  # The single line that becomes flake.nix's outputs (regenerate with
  # `nix run .#write-flake`).
  flake-file.outputs = ''
    inputs: inputs.flake-parts.lib.mkFlake {inherit inputs;} (inputs.import-tree ./modules)
  '';

  systems = [
    "aarch64-darwin"
    "aarch64-linux"
    "x86_64-darwin"
    "x86_64-linux"
  ];
}
