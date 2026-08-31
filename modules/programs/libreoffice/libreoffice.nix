{
  # LibreOffice: a FOSS, professional-quality office suite (Writer, Calc, …).
  #
  # Cross-platform: the suite ships differently per OS, so each branch picks
  # the right package. Linux builds the Qt variant from source and finds its
  # spell-check dictionaries from the profile's hunspell share dir. macOS has no
  # source build, so nixpkgs ships the official prebuilt LibreOffice.app
  # (libreoffice-bin), which bundles its own spell checking; mac-app-util
  # trampolines that bundle into Launchpad/Spotlight (see the mac-app-util feature).
  flake.modules.homeManager.libreoffice = {
    pkgs,
    lib,
    ...
  }:
    lib.mkMerge [
      (lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        home.packages = with pkgs; [
          libreoffice-qt-stable
          hunspell # Spell-check engine for LibreOffice
          hunspellDicts.en_US # US English dictionary
        ];
      })
      (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
        home.packages = [pkgs.libreoffice-bin];
      })
    ];
}
