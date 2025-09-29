# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:

{
  # Experimental nix settings
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  imports =
    [
      ./hardware-configuration.nix
    ];

  # Files for secrets management
  sops = {
    defaultSopsFile = ./secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = "/etc/nixos/secrets/keys.txt";
    secrets.hashedPasswordJakeNeau.neededForUsers = true;
  };

  # Bootloader.
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
          chainloader (''\${root})/EFI/Microsoft/Boot/bootmgfw.efi
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
  system.nixos.label = "test";

  boot.kernelParams = [ "video=5120x1440" ];

  boot.initrd.luks.devices."luks-014e6aef-d36f-4b5b-9b48-447d6bc40b95".device = "/dev/disk/by-uuid/014e6aef-d36f-4b5b-9b48-447d6bc40b95";
  networking.hostName = "nixos"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/Chicago";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services.xserver.enable = true;

  # Display manager: handles login
  # services.displayManager.sddm.enable = true;

  # Compositor: displays the desktop
  programs.hyprland.enable = true;

  # Enable other desktop portals for screen sharing
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
    ];
  };

  # Configure keymap
  services.xserver.xkb = {
    layout = "us";
    variant = "";
    options = "ctrl:nocaps";
  };
  console.useXkbConfig = true;

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Configure hardware settings for AMD GPUs
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.mutableUsers= false;
  users.users.jakeneau = {
    isNormalUser = true;
    description = "Jake Neau";
    extraGroups = [ "networkmanager" "wheel" ];
    hashedPasswordFile = config.sops.secrets.hashedPasswordJakeNeau.path;
  };

  # Set users of the wheel group to not need sudo passwords
  security.sudo.wheelNeedsPassword = false;

  # Enable automatic login for the user.
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "jakeneau";

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Default version control software
  programs.git = {
    enable = true;
    config = { 
      init.defaultBranch = "main";
      user.name = "Jake Neau";
      user.email = "jakeneau@proton.me";
    };
  };

  # Declarative Neovim distrobution
  programs.nvf = {
    enable = true;
    defaultEditor = true;
    settings = {
      vim = {
        viAlias = false;
        vimAlias = true;
        lsp = {
          enable = true;
        };
       
        statusline.lualine.enable = true;
        telescope.enable = true;
        autocomplete.nvim-cmp.enable = true;
      };
    };

  };

  # PC game platform
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
  };


  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    bitwarden-desktop                     # Password manager for all devices
    blender-hip                           # 3D Modeling art program with AMD GPU support (hip)
    (bottles.override {                   # A wine prefix manager
      removeWarningPopup = true;
    })
    candy-icons                           # A gradient vector icon theme
    eza                                   # A better version of ls written in rust
    fastfetch                             # Terminal program for displaying system info and flexing on arch users
    fishPlugins.colored-man-pages         # More interesting man pages
    fishPlugins.fish-bd                   # Go back directories with bd
    fishPlugins.forgit                    # Interactive git editor
    fishPlugins.fzf-fish                  # Search for multiple things with fzf
    fishPlugins.grc                       # A generic colorizer
    fishPlugins.pisces                    # Adds parentheses, quotes, etc. in pairs
    fishPlugins.plugin-sudope             # Add sudo to a command when you forgot
    fishPlugins.plugin-git                # Git aliases for fish
    fishPlugins.puffer                    # Useful text expansions
    fishPlugins.pure                      # Minimal and fast fish prompt
    fishPlugins.sponge                    # Remove typos from terminal
    fishPlugins.z                         # Jump to previous directories
    freecad                               # An open source CAD program
    fuzzel                                # Super fast application launcher
    fzf                                   # System wide fuzzy finder
    ghostty                               # A fast and GPU accelerated terminal emulator
    grc                                   # Generic text colorizer
    hyprpaper                             # Hyprland wallpaper utility
    inkscape                              # Vector graphics editor
    jdk21                                 # Java Development Kit
    jujutsu                               # A better VCS built on top of git
    librewolf                             # Firefox based browser with more privacy
    obs-studio                            # Screen recording software
    obsidian                              # Note taking utility using markdown files
    pavucontrol                           # Sound setting control GUI
    playerctl                             # Keyboard controls for audio players
    prismlauncher                         # Minecraft launcher
    sops                                  # CLI tools for secrets management
    spotify                               # Music subscription service
    todoist-electron                      # Todo tracker app
    vesktop                               # Alternative to discord messaging app
    wget                                  # Download web files from the command line 
  ];

  programs.bash = {
    enable = true;
    interactiveShellInit = ''
      if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]
      then
        shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
        exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
      fi
    '';
  };
  programs.fish = {
    enable = true;
    shellAliases = {
      # NixOS Aliases
      nf = "sudoedit /etc/nixos/flake.nix";
      nc = "sudoedit /etc/nixos/configuration.nix";
      nh = "$EDITOR /etc/nixos/users/$USER/home.nix";
      nr = "sudo nix flake update --flake /etc/nixos; sudo nixos-rebuild switch --upgrade --flake /etc/nixos";
      ng = "sudo nix-collect-garbage --delete-old";
      ns = "sops /etc/nixos/secrets/secrets.yaml";

      # General Command Aliases
      l = "eza -alh --git-repos --git";
      r = "sudo systemctl reboot";
      s = "sudo systemctl poweroff";
    };
  };

  # Style system with stylix
  stylix = {
    enable = true;

    # Set color scheme
    base16Scheme = "${pkgs.base16-schemes}/share/themes/tarot.yaml";
    polarity = "dark";

    # Set Wallpaper
    image = ./wallpapers/mountain-sunset.jpg;

    # Set cursor
    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 24;
    };

    # Set fonts
    fonts = {
      monospace = {
        package = pkgs.fira-code;
	name = "fira-code";
      };
      sansSerif = {
        package = pkgs.montserrat;
	name = "montserrat";
      };
      serif = {
        package = pkgs.zilla-slab;
	name = "zilla-slab";
      };
    };
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 25565 ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?

}
