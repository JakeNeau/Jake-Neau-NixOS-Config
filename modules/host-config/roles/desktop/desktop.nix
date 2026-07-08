{inputs, ...}: {
  # Coarse "desktop" layer shared by every NixOS workstation (desktop + laptop).
  # First-pass dendritic move: this is intentionally one large module. Split
  # individual features (niri, audio, shell, fonts, …) out of here over time.

  flake.modules.nixos.role-desktop = {
    config,
    pkgs,
    lib,
    ...
  }: {
    imports =
      (with inputs.self.modules.nixos; [
        role-default
        stylix
        caps-dual-role
        fish
        podman
        niri-desktop
        audio
        graphics
        network
        ungoogled-chromium
        blender
        davinci-resolve
        spotify
      ])
      ++ [inputs.self.modules.generic.cli];

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

    # ------
    # Keymap
    # ------
    services.xserver.xkb = {
      layout = "us";
      variant = "";
      options = ""; # Caps lock behavior is owned by the caps-dual-role feature (kanata)
    };
    console.useXkbConfig = true;

    # ----------------
    # Security & login
    # ----------------
    security.sudo.wheelNeedsPassword = false;

    # Enable polkit for running privledged operations
    security.polkit.enable = true;

    # Enable Gnome Keyring for staying logged into applications
    services.gnome.gnome-keyring.enable = true;
    security.pam.services.greetd.enableGnomeKeyring = true;

    # --------
    # Packages
    # --------
    environment.systemPackages = with pkgs; [
      vscode
      audacity # Audio recording program
      bitwarden-desktop # Password manager for all devices
      bluetui # A tui for managing bluetooth
      # (bottles.override {
      #   # A wine prefix manager
      #   removeWarningPopup = true;
      # })
      ckan # A mod manager for Kerbal Space Program
      element-desktop # A group messaging service with an open source API
      freecad # An open source parametric 3D modeling program
      gnucash # Double-entry accounting software
      inkscape # Vector graphics editor
      krita # A FOSS art program
      mpv # General purpose video player
      obs-studio # Screen recording software
      obsidian # Note taking utility using markdown files
      playerctl # Keyboard controls for audio players
      prismlauncher # Minecraft launcher
      loupe # Fast and lightweight image viewer
      reaper # A configurable digital audio workstation
      signal-desktop # A private messaging service
      todoist-electron # Todo tracker app
      vesktop # Alternative to discord messaging app
      xournalpp # App for signing PDFs
    ];

    # Temporary: still pinned by bitwarden-desktop upstream. Drop once nixpkgs
    # bumps it off EOL electron.
    nixpkgs.config.permittedInsecurePackages = [
      "electron-39.8.10" # bitwarden-desktop's runtime engine
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
  flake.modules.darwin.role-desktop = {
    imports = with inputs.self.modules.darwin; [
      role-default
      fish
      ghostty
      graphics
      homebrew
      karabiner
      key-repeat
      mac-app-util
      ungoogled-chromium
    ];
  };

  # Home-manager desktop env shared by every user: the editor + CLI tools.
  flake.modules.homeManager.role-desktop = {
    imports = with inputs.self.modules.homeManager; [
      role-default
      nvf
      claude-code
      cli-tools
      caps-dual-role
      copy-paste-remaps
      fish
      ghostty
      karabiner
      beekeeper-studio
      libreoffice
      sioyek
    ];
  };
}
