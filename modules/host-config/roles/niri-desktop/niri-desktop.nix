{ inputs, ... }: {
  # niri-desktop: the complete niri wayland desktop in one import -- the compositor,
  # its portals, the greetd session that launches it, and (via home-manager) all the
  # per-user wayland plumbing. NixOS-only; niri does not exist on macOS.

  flake.modules.nixos.niri-desktop = { pkgs, ... }: {
    imports = with inputs.self.modules.nixos; [
      hyprlock
    ];

    programs.niri = {
      enable = true;
      package = pkgs.niri;
    };

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
  flake.modules.homeManager.niri-desktop =
    { pkgs, ... }:
    let
      zeroGapConfig = pkgs.writeText "niri-zero-gap-config.kdl" (
        builtins.replaceStrings [ "gaps 12" ] [ "gaps 0" ] (builtins.readFile ./config.kdl)
      );
      toggle-16-9 = pkgs.writeShellApplication {
        name = "niri-toggle-16-9";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.jq
          pkgs.niri
        ];
        text = ''
          normal_config="${./config.kdl}"
          zero_gap_config="${zeroGapConfig}"
          ${builtins.readFile ./toggle-16-9.sh}
        '';
      };
    in
    {
      imports = with inputs.self.modules.homeManager; [
        swaybg
        wl-clipboard
        wl-clip-persist
        clipse
        fuzzel
        hyprlock
        udiskie
        xwayland-satellite
        candy-icons
        papirus-icon-theme
        hidden-desktop-entries
      ];

      home.packages = [ toggle-16-9 ];

      xdg.configFile."niri/config.kdl".source = ./config.kdl;
    };
}
