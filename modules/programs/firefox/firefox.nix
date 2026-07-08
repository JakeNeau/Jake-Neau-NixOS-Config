{
  # Firefox, the multi-way case: home-manager per-user install by default
  # on both platforms, plus the macOS cask for hosts where the nix package
  # breaks (cedar's org SSO). Cedar's host declaration switches to the cask
  # at the stage-5 cutover; until then its hand-written cask line delivers.
  #
  # No shared HM config exists yet, so no config field and no
  # programs.firefox.enable = true: cask hosts just run firefox, and a user
  # who enables it for HM config gets the -config unit's package = null
  # instead of the broken-there nix package.
  flake.programs.firefox = {
    install.linux = ["home"];
    install.macos = ["home" "cask"];
  };
}
