{
  # Microsoft OneDrive, macOS-only: nixpkgs onedrive is Linux-only, so the
  # app can only come from the homebrew cask — there is no Linux/system way.
  flake.programs.onedrive = {
    install.macos = ["cask"];
    # false so the generated -config unit is just the (empty) shared config.
    # home-manager's programs.onedrive is a Linux-only daemon module (its
    # default package isn't available on darwin), never applicable on a
    # cask host, and there is no per-user config to manage. Default true
    # would instead emit an inert programs.onedrive.package = null stub.
    hasEnableOption = false;
  };
}
