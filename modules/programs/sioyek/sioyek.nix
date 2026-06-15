{
  # Sioyek: a keyboard-driven PDF reader built for papers and textbooks
  # (vim-flavored keybindings, marks/bookmarks, smart citation jumping).
  #
  # Cross-platform [nd]: nixpkgs builds sioyek on both Linux and macOS, so a
  # single home-manager aspect installs it everywhere. home-manager has no
  # `programs.sioyek` module yet, so it ships as a plain package; drop a
  # `keys.config` / `prefs.config` under ~/.config/sioyek to customize.

  flake.modules.homeManager.sioyek = {pkgs, ...}: {
    home.packages = [pkgs.sioyek];
  };
}
