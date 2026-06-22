{
  # jujutsu (jj): a git-compatible VCS, configured through home-manager so it's
  # shared by every user on every system.
  flake.modules.homeManager.jujutsu = {
    programs.jujutsu = {
      enable = true;
      settings.user = {
        name = "Jake Neau";
        email = "jakeneau@proton.me";
      };
    };
  };
}
