{
  # Noctalia: a Wayland desktop shell with a bar, notifications, and a launcher.
  flake.programs.noctalia = {
    install.linux = [ "home" ];
    config.programs.noctalia.systemd.enable = true;
  };
}
