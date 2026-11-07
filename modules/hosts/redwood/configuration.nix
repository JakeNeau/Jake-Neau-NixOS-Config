{ inputs, ... }: {
  # The NixOS desktop ("redwood"). Shared desktop config comes from
  # role-desktop; this file holds only desktop-specific hardware/features.
  flake.hosts.redwood = {
    class = "nixos";
    system = "x86_64-linux";
    users = [ "jakeneau" ];
    globalPrograms = [
      "ghostty"
      "yazi"
      "fastfetch"
      "gh"
      "home-assistant"
      "home-assistant-filesystem"
      "mullvad-vpn"
      "nautilus"
      "openpencil"
      "steam"
      "ungoogled-chromium"
    ];
    baselines = [
      "role-desktop"
      "niri-desktop"
      "stylix"
      "steamvr"
    ];
  };

  flake.modules.nixos.redwood = { pkgs, ... }: {
    imports =
      (with inputs.self.modules.nixos; [
        role-desktop
        lanzaboote
        nix-minecraft
        home-assistant-filesystem
        steamvr
      ])
      ++ [ inputs.self.modules.generic.numtide-cache ];

    hostConstants.hostName = "redwood";
    hostConstants.displayResolution = {
      horizontal = 5120;
      vertical = 1440;
    };

    # Host facts features branch on (e.g. the graphics vendor modules).
    hostConstants.graphicsType = "amd";

    # ----
    # Boot
    # ----
    boot.loader.timeout = 10;
    # The relocated 5 GiB EFI partition has room for 15 boot generations.
    boot.lanzaboote.configurationLimit = 15;

    # Redwood's firmware supports S3, while s2idle wedges the AMD resume path.
    systemd.sleep.settings.Sleep = {
      MemorySleepMode = "deep";
      SuspendState = "mem";
    };
    boot.initrd.luks.devices."luks-014e6aef-d36f-4b5b-9b48-447d6bc40b95".device =
      "/dev/disk/by-uuid/014e6aef-d36f-4b5b-9b48-447d6bc40b95";

    # --------------
    # Steam / gaming
    # --------------
    # PC game platform. The steam declaration installs it and excludes it
    # from the VPN. These are redwood's own settings.
    programs.steam = {
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
      gamescopeSession.enable = true;
      # Steam's bundled Fontconfig becomes unstable with the complete system catalog.
      fontPackages = with pkgs; [
        dejavu_fonts
        liberation_ttf
        montserrat
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-color-emoji
      ];
      extraCompatPackages = with pkgs; [
        proton-ge-bin
      ];
    };

    # -------
    # OpenRGB
    # -------
    # RGB control software
    services.hardware.openrgb = {
      enable = true;
      startupProfile = "orange";
    };

    # ----------------
    # Minecraft server
    # ----------------
    # Server definitions only; the enable (and the hostConstants fact) come
    # from importing the nix-minecraft feature.
    services.minecraft-servers = {
      eula = true;
      openFirewall = true;

      servers = {
        vanilla-optimized = {
          enable = true;
          autoStart = false;
          package = pkgs.purpurServers.purpur-1_21_11;
        };
      };
    };

    # -------------
    # State version
    # -------------
    # The first system version installed.
    # Do not change unless you know what you are doing, things will break.
    system.stateVersion = "24.11";
  };
}
