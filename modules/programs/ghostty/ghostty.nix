{
  # Ghostty: a fast, GPU accelerated terminal emulator, on every machine.
  #
  # Linux: home-manager installs the package and manages the config.
  # macOS: the app comes from the homebrew cask (no darwin build in
  #        nixpkgs); home-manager only manages the config.
  #
  # Related: copy/paste keybinds come from modules/host-config/copy-paste-remaps.

  flake.programs.ghostty = {
    linux.install = [ "home" ];
    macos.install = [ "cask" ];

    shared.config.programs.ghostty = {
      # enable stays here, not just in the generated Linux-gated install:
      # with package = null it is what makes macOS config-only — HM still
      # writes the config for the cask-installed app.
      enable = true;
      enableFishIntegration = true;
      settings = {
        background-opacity = 0.9;
        font-feature = [
          "liga"
          "calt"
          "dlig"
        ];
        # Send Option as Alt so Neovim's <A-…> maps fire; the cost is losing
        # Option-composed special characters on macOS.
        macos-option-as-alt = true;
        keybind = [
          "ctrl+enter=unbind"
        ];
      };
    };

    macos.config = {
      programs.ghostty = {
        package = null;
        # stylix themes ghostty on Linux; the macs have no stylix, so use
        # ghostty's bundled theme matching the stylix scheme (same accents as
        # everforest-dark-hard.yaml).
        settings.theme = "Everforest Dark Hard";
      };

      # Silence the "Last login: ..." banner login(1) prints in every new
      # terminal window on macOS.
      home.file.".hushlogin".text = "";
    };
  };
}
