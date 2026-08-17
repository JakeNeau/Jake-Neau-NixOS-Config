{
  # Baseline settings every home-manager user needs.
  flake.modules.homeManager.role-minimal = {
    config,
    pkgs,
    lib,
    ...
  }: {
    home.homeDirectory =
      if pkgs.stdenv.hostPlatform.isDarwin
      then lib.mkForce "/Users/${config.home.username}"
      else "/home/${config.home.username}";

    # home-manager release this config targets (update deliberately).
    home.stateVersion = "25.05";
  };
}
