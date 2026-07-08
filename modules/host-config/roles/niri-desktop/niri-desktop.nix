{inputs, ...}: {
  # niri-desktop: the complete niri wayland desktop in one import -- the compositor,
  # its portals, the greetd session that launches it, and (via home-manager) all the
  # per-user wayland plumbing. NixOS-only; niri does not exist on macOS.

  flake.modules.nixos.niri-desktop = {pkgs, ...}: {
    programs.niri.enable = true;

    xdg.portal = {
      enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-gnome
        pkgs.xdg-desktop-portal-gtk
      ];
    };

    # Greeter: launches the niri session at login
    services.greetd = {
      enable = true;
      settings = rec {
        initial_session = {
          command = "${pkgs.niri}/bin/niri-session -l";
          user = "jakeneau";
        };
        default_session = initial_session;
      };
    };
  };

  # Per-user wayland plumbing, aggregated -- each tool is its own feature.
  # Rides the niri hosts' baselines (a flake.hosts baselines entry), which
  # keeps it off macOS, where these same users also live.
  flake.modules.homeManager.niri-desktop = {
    imports = with inputs.self.modules.homeManager; [
      swaybg
      wl-clipboard
      wl-clip-persist
      clipse
      fuzzel
      udiskie
      xwayland-satellite
      candy-icons
      papirus-icon-theme
      hidden-desktop-entries
    ];
  };
}
