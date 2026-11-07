{
  # Install-only: no HM programs.kubernetes module exists, so the generator
  # supplies the enable toggle and installs the tools behind it.
  flake.programs.kubernetes = {
    shared.install = [ "home" ];
    hasEnableOption = false;
    shared.packages = pkgs: [
      pkgs.kubectl # Kubernetes CLI
      pkgs.k9s # terminal UI for managing clusters
    ];
  };
}
