{
  # Ghostty: a fast, GPU accelerated terminal emulator, on every machine.
  #
  # NixOS [n]: home-manager installs the package and manages the config.
  # macOS [d]: the app comes from the homebrew cask (no darwin build in
  #            nixpkgs); home-manager only manages the config.
  #
  # Related: copy/paste keybinds come from modules/system/copy-paste-remaps.

  flake.modules.darwin.ghostty = {
    homebrew.casks = ["ghostty"];
  };

  flake.modules.homeManager.ghostty = {
    pkgs,
    lib,
    ...
  }: {
    programs.ghostty = {
      enable = true;
      package = lib.mkIf pkgs.stdenv.isDarwin null;
      enableFishIntegration = true;
      settings = {
        background-opacity = 0.8;
        font-feature = ["liga" "calt" "dlig"];
        keybind = [
          "ctrl+enter=unbind"
        ];
      };
    };
  };
}
