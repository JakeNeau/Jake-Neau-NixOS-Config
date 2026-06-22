{inputs, ...}: {
  # Jake's home environment. The cross-platform core (git, jujutsu, …) comes
  # from system-default via system-desktop; platform-specific desktop programs
  # live in their own features (e.g. the niri-desktop system), not here.
  flake.modules.homeManager.jakeneau = {
    imports = with inputs.self.modules.homeManager; [
      system-desktop
      librewolf
    ];
  };
}
