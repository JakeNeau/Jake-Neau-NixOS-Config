{inputs, ...}: {
  # Jake's home environment. The cross-platform core (git, jujutsu, …) comes
  # from role-default via role-desktop; platform-specific desktop programs
  # live in their own features (e.g. the niri-desktop system), not here.
  flake.modules.homeManager.jakeneau = {
    imports = with inputs.self.modules.homeManager; [
      role-desktop
      librewolf
    ];
  };
}
