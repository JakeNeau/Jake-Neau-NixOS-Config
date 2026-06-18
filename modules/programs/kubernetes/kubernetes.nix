{
  flake.modules.homeManager.kubernetes = {pkgs, ...}: {
    home.packages = with pkgs; [
      kubectl # Kubernetes CLI
      k9s # terminal UI for managing clusters
    ];
  };
}
