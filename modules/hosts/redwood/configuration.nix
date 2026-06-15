{inputs, ...}: {
  # The NixOS desktop ("redwood"). Shared desktop config comes from
  # system-desktop; this file holds only desktop-specific hardware/features.
  flake.modules.nixos.redwood = {pkgs, ...}: {
    imports = with inputs.self.modules.nixos; [
      system-desktop
      fastfetch
      minegrub
      nix-minecraft
      jakeneau
    ];

    networking.hostName = "redwood";

    # ----
    # Boot
    # ----
    boot.loader = {
      efi.canTouchEfiVariables = true;
      grub = {
        enable = true;
        device = "nodev";
        efiSupport = true;
        minegrub-theme = {
          enable = true;
          splash = "I use NixOS BTW!!";
          background = "background_options/1.8  - [Classic Minecraft].png";
          boot-options-count = 4;
        };
        gfxmodeEfi = "5120x1440";
        gfxmodeBios = "5120x1440";
        extraEntries = ''
          menuentry "Windows 11 (Skill Issue)" {
            search --fs-uuid --no-floppy --set=root 4443-0F45
            chainloader (''${root})/EFI/Microsoft/Boot/bootmgfw.efi
          }
          menuentry "UEFI Firmware Settings" {
            fwsetup
          }
        '';
        extraConfig = ''
          GRUB_TIMEOUT=10
        '';
      };
    };
    stylix.targets.grub.enable = false;

    boot.kernelParams = ["video=5120x1440"];

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

    # ---
    # GPU
    # ---
    # Configure hardware settings for AMD GPUs
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        # Needed for Davinci Resolve
        rocmPackages.clr.icd
        mesa.opencl
      ];
    };
    nixpkgs.config.rocmSupport = true;

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

    # -----------
    # Environment
    # -----------
    # Desktop-specific environment variables (RUSTICL for the AMD GPU).
    environment.variables = {
      RUSTICL_ENABLE = "radeonsi";
    };

    # ----------------
    # Minecraft server
    # ----------------
    # A declaratively configured minecraft server
    services.minecraft-servers = {
      enable = true;
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
