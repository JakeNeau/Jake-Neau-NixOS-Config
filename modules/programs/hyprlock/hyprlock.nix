{
  flake.modules.nixos.hyprlock = {
    security.pam.services.hyprlock = {};
  };

  flake.modules.homeManager.hyprlock = {
    programs.hyprlock.enable = true;
  };
}
