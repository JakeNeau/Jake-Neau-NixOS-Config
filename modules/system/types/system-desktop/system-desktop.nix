{inputs, ...}: {
  # Coarse "desktop" layer shared by every NixOS workstation (desktop + laptop).
  # First-pass dendritic move: this is intentionally one large module. Split
  # individual features (niri, audio, shell, fonts, …) out of here over time.

  flake.modules.nixos.system-desktop = {
    config,
    pkgs,
    lib,
    ...
  }: {
    imports =
      (with inputs.self.modules.nixos; [
        system-default
        stylix
        caps-dual-role
        fish
        podman
      ])
      ++ [inputs.self.modules.generic.cli];

    # ----------
    # Networking
    # ----------
    networking.wireless.iwd = {
      enable = true;
      settings = {
        IPv6 = {
          Enabled = true;
        };
        Settings = {
          AutoConnect = true;
        };
      };
    };

    networking.networkmanager = {
      enable = true;
      wifi.backend = "iwd";
    };

    # ---------
    # Bluetooth
    # ---------
    hardware.bluetooth.enable = true;

    # -------------
    # Locale & time
    # -------------
    time.timeZone = "America/Chicago";

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

    # -------
    # Desktop
    # -------
    # Compositor: displays the desktop
    programs.niri.enable = true;

    xdg.portal = {
      enable = true;
      extraPortals = [
        pkgs.xdg-desktop-portal-gnome
        pkgs.xdg-desktop-portal-gtk
      ];
    };

    # ------
    # Keymap
    # ------
    services.xserver.xkb = {
      layout = "us";
      variant = "";
      options = ""; # Caps lock behavior is owned by the caps-dual-role feature (kanata)
    };
    console.useXkbConfig = true;

    # --------
    # Printing
    # --------
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };

    services.printing = {
      enable = true;
      drivers = with pkgs; [
        cups-filters
        cups-browsed
      ];
    };

    # -----
    # Audio
    # -----
    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };

    # ----------------
    # Security & login
    # ----------------
    security.sudo.wheelNeedsPassword = false;

    # Enable polkit for running privledged operations
    security.polkit.enable = true;

    # Greeter: handles login
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

    # Enable Gnome Keyring for staying logged into applications
    services.gnome.gnome-keyring.enable = true;
    security.pam.services.greetd.enableGnomeKeyring = true;

    # --------
    # Programs
    # --------
    # direnv will load nix configs automatically in project folders
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    # Default version control software
    programs.git = {
      enable = true;
      config = {
        user.name = "Jake Neau";
        user.email = "jakeneau@proton.me";
        init.defaultBranch = "main";
        safe.directory = "/etc/nixos";
      };
    };

    # --------
    # Packages
    # --------
    environment.systemPackages = with pkgs; [
      vscode
      audacity # Audio recording program
      bitwarden-desktop # Password manager for all devices
      blender # 3D Modeling art program with AMD GPU support (hip)
      bluetui # A tui for managing bluetooth
      # (bottles.override {
      #   # A wine prefix manager
      #   removeWarningPopup = true;
      # })
      candy-icons # A gradient vector icon theme
      clipse # A cool clipboard manager
      ckan # A mod manager for Kerbal Space Program
      davinci-resolve-studio # Professional video editor
      element-desktop # A group messaging service with an open source API
      freecad # An open source parametric 3D modeling program
      fuzzel # Super fast application launcher
      gnucash # Double-entry accounting software
      hunspell # Spell check needed for LibreOffice
      hunspellDicts.en_US # US English dictionary for Hunspell
      inkscape # Vector graphics editor
      krita # A FOSS art program
      libreoffice-qt-fresh # A FOSS office suite
      mpv # General purpose video player
      obs-studio # Screen recording software
      obsidian # Note taking utility using markdown files
      papirus-icon-theme # Fallback icon set
      pavucontrol # Sound setting control GUI
      playerctl # Keyboard controls for audio players
      prismlauncher # Minecraft launcher
      loupe # Fast and lightweight image viewer
      qpwgraph # A patchbay and volume control program that works with pipewire
      reaper # A configurable digital audio workstation
      signal-desktop # A private messaging service
      spotify # Music subscription service
      swaybg # Wallpaper utility
      todoist-electron # Todo tracker app
      udiskie # Automounting for removable media
      ungoogled-chromium # Chromium without all the callbacks to google
      vesktop # Alternative to discord messaging app
      wl-clip-persist # Make sure clipboard items persist after programs close
      wl-clipboard # Clipboard manager backend
      xournalpp # App for signing PDFs
      xwayland-satellite # Xwayland compatability for wayland only compositors
    ];

    # -----
    # Fonts
    # -----
    fonts = {
      packages = with pkgs; [
        google-fonts
        noto-fonts
        noto-fonts-cjk-sans
        noto-fonts-color-emoji
        liberation_ttf
      ];
      fontDir.enable = true;
    };

    # -----------
    # Environment
    # -----------
    environment.variables = {
      NIX_ROOT = "/etc/nixos";
    };
  };

  # Darwin desktop layer (room to grow; base is enough today).
  flake.modules.darwin.system-desktop = {
    imports = with inputs.self.modules.darwin; [
      system-default
      fish
      ghostty
      homebrew
      karabiner
      mac-app-util
    ];
  };

  # Home-manager desktop env shared by every user: the editor + CLI tools.
  flake.modules.homeManager.system-desktop = {
    imports = with inputs.self.modules.homeManager; [
      system-default
      nvf
      claude-code
      cli-tools
      caps-dual-role
      copy-paste-remaps
      fish
      ghostty
      karabiner
      sioyek
    ];
  };
}
