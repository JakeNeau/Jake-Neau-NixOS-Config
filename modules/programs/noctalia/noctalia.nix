let
  twelveHour = "{:%-I:%M %p}"; # e.g. "9:05 AM"
in
{
  # Noctalia: a Wayland desktop shell with a bar, notifications, and a launcher.
  flake.programs.noctalia = {
    linux.install = [ "home" ];
    shared.config.programs.noctalia = {
      systemd.enable = true;
      settings = {
        shell.time_format = twelveHour;
        widget.clock.format = twelveHour;
      };
    };
  };
}
