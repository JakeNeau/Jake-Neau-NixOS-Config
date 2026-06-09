{
  # Cross-platform command-line tools, configured through home-manager.

  flake.modules.homeManager.cli-tools = {
    programs.eza = {
      enable = true;
      colors = "always";
      icons = "always";
      enableFishIntegration = true;
      extraOptions = [
        "--group-directories-first"
      ];
    };

    programs.fzf = {
      enable = true;
      enableFishIntegration = true;
    };
  };
}
