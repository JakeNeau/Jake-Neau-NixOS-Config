{
  # Windows App (formerly Microsoft Remote Desktop), a closed-source macOS GUI
  # app with no nixpkgs darwin package — the homebrew cask is the only install
  # path. Cask token is the declaration name, so this must be "windows-app".
  flake.programs.windows-app = {
    install.macos = ["cask"];
    # false so the generated -config unit is just the (empty) shared config.
    # There is no home-manager module for this app and no per-user config to
    # manage; default true would instead emit an inert package = null stub.
    hasEnableOption = false;
  };
}
