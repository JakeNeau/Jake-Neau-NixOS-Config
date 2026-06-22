{
  # git identity in two aspects so it matches at both levels: the home-manager
  # aspect for per-user git, the nixos aspect for system-level /etc/gitconfig.
  flake.modules.homeManager.git = {
    programs.git = {
      enable = true;
      settings.user = {
        name = "Jake Neau";
        email = "jakeneau@proton.me";
      };
    };
  };

  flake.modules.nixos.git = {
    programs.git = {
      enable = true;
      config = {
        user.name = "Jake Neau";
        user.email = "jakeneau@proton.me";
        init.defaultBranch = "main";
      };
    };
  };
}
