{inputs, ...}: {
  # The NixOS desktop ("redwood"). Shared desktop config comes from
  # role-desktop; this file holds only desktop-specific hardware/features.
  flake.hosts.redwood = {
    class = "nixos";
    system = "x86_64-linux";
    users = ["jakeneau"];
    globalPrograms = ["ghostty" "yazi" "fastfetch" "gh" "nautilus" "openpencil"];
    baselines = ["role-desktop" "niri-desktop" "redwood-monitor-power" "stylix"];
  };

  flake.modules.homeManager.redwood-monitor-power = {pkgs, ...}: let
    redwoodSamsungOdysseyG9Power = inputs.self.lib.monitorPower.samsungTizen {
      inherit pkgs;
      name = "redwood-samsung-odyssey-g9-power";
      hostname = "samsung.local";
      tokenFile = "/run/secrets/redwoodSamsungOdysseyG9Token";
      remoteName = "redwood-monitor-power";
    };
  in {
    monitorPower = {
      ddc.enable = true;
      backends.redwoodSamsungOdysseyG9 = redwoodSamsungOdysseyG9Power;
      resumeAfterSleep.enable = true;
      screenOff.wakeOnInput.enable = true;
    };
  };

  flake.modules.nixos.redwood = {pkgs, ...}: {
    imports =
      (with inputs.self.modules.nixos; [
        role-desktop
        nix-minecraft
      ])
      ++ [inputs.self.modules.generic.numtide-cache];

    hostConstants.hostName = "redwood";
    hostConstants.displayResolution = {
      horizontal = 5120;
      vertical = 1440;
    };

    sops.secrets.redwoodSamsungOdysseyG9Token.owner = "jakeneau";

    # Host facts features branch on (e.g. the graphics vendor modules).
    hostConstants.graphicsType = "amd";

    # ----
    # Boot
    # ----
    boot.loader.timeout = 10;
    boot.loader.grub = {
      # Bound /boot/kernels so the 511M partition never fills; older
      # generations stay in the store but drop out of the GRUB menu.
      configurationLimit = 15;
      extraEntries = ''
        menuentry "Windows 11 (Skill Issue)" --class windows {
          search --fs-uuid --no-floppy --set=root 4443-0F45
          chainloader (''${root})/EFI/Microsoft/Boot/bootmgfw.efi
        }
        menuentry "UEFI Firmware Settings" --class efi {
          fwsetup
        }
      '';
    };

    # Redwood's firmware supports S3, while s2idle wedges the AMD resume path.
    systemd.sleep.settings.Sleep = {
      MemorySleepMode = "deep";
      SuspendState = "mem";
    };
    monitorPower.resumeUsers = ["jakeneau"];

    boot.kernelPatches = [
      {
        # Patches for running steamVR
        name = "amdgpu-ignore-ctx-privileges";
        patch = pkgs.fetchpatch {
          name = "cap_sys_nice_begone.patch";
          url = "https://github.com/Frogging-Family/community-patches/raw/master/linux61-tkg/cap_sys_nice_begone.mypatch";
          hash = "sha256-Y3a0+x2xvHsfLax/uwycdJf3xLxvVfkfDVqjkxNaYEo=";
        };
      }
    ];

    boot.initrd.luks.devices."luks-014e6aef-d36f-4b5b-9b48-447d6bc40b95".device = "/dev/disk/by-uuid/014e6aef-d36f-4b5b-9b48-447d6bc40b95";

    # -----
    # Audio
    # -----
    # Replicate audio output to multiple sinks (Focusrite + FiiO).
    services.pipewire.extraConfig.pipewire = {
      "91-null-sinks" = {
        "context.objects" = [
          {
            factory = "adapter";
            args = {
              "factory.name" = "support.null-audio-sink";
              "node.name" = "Multi-Output";
              "node.desctiption" = "Replicates output to multiple sinks";
              "media.class" = "Audio/Sink";
              "audio.position" = "FL,FR";
            };
          }
        ];
      };
    };

    # Run pipewire setup scripts on startup
    systemd.user.services.create-pipewire-links = {
      description = "create-pipewire-links: sets up pipewire connections after pipewire is set up";
      wantedBy = [
        "pipewire.service"
      ];
      requires = [
        "pipewire.service"
        "wireplumber.service"
      ];
      after = [
        "pipewire.service"
        "wireplumber.service"
      ];
      preStart = "sleep 5";
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = 5;
      };
      script = ''
        # ports obtained from `pw-link -io`

        # Connect multi-output to focusrite headphones
        /run/current-system/sw/bin/pw-link "Multi-Output:monitor_FL" "alsa_output.usb-Focusrite_Scarlett_2i2_USB_Y8XBPE40BA5F9E-00.HiFi__Line1__sink:playback_FL"
        /run/current-system/sw/bin/pw-link "Multi-Output:monitor_FR" "alsa_output.usb-Focusrite_Scarlett_2i2_USB_Y8XBPE40BA5F9E-00.HiFi__Line1__sink:playback_FR"

        # Connect multi-output to fiio amp
        /run/current-system/sw/bin/pw-link "Multi-Output:monitor_FL" "alsa_output.usb-GuangZhou_FiiO_Electronics_Co._Ltd_FiiO_K7-00.analog-stereo:playback_FL"
        /run/current-system/sw/bin/pw-link "Multi-Output:monitor_FR" "alsa_output.usb-GuangZhou_FiiO_Electronics_Co._Ltd_FiiO_K7-00.analog-stereo:playback_FR"
      '';
    };

    # --------------
    # Steam / gaming
    # --------------
    # PC game platform
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
      gamescopeSession.enable = true;
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
