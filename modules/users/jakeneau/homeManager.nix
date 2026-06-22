{inputs, ...}: {
  # Jake's home environment: the cross-platform core (git, jujutsu) layered on the
  # shared desktop and browser features. Platform-specific desktop programs live in
  # their own features (e.g. the niri-desktop system), not here.
  flake.modules.homeManager.jakeneau = {
    imports = with inputs.self.modules.homeManager; [
      system-desktop
      librewolf
    ];

    programs.git = {
      enable = true;
      settings.user = {
        name = "Jake Neau";
        email = "jakeneau@proton.me";
      };
    };

    programs.jujutsu = {
      enable = true;
      settings.user = {
        name = "Jake Neau";
        email = "jakeneau@proton.me";
      };
    };
  };
}
