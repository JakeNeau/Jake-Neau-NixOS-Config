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

    # polkit lets desktop apps run privileged operations
    security.polkit.enable = true;

    # gnome keyring keeps applications logged in across sessions
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
      # Remove once nixos-unstable contains NixOS/nixpkgs#537721.
      (freecad.override {
        python3Packages = python3Packages.overrideScope (_: previous: {
          vtk = previous.vtk.overrideAttrs (old: {
            patches =
              (old.patches or [])
              ++ [
                (fetchpatch {
                  name = "fix-gdal-3.13-const-conversion.patch";
                  url = "https://github.com/Kitware/VTK/commit/2395603fdddc40c29efc64c632ae98225ca2a58e.patch";
                  hash = "sha256-Gcnt1JXWPkhfNLhtk9SXYqx/0cLkjO4xiRfR8YiaY8I=";
                })
              ];
          });
        });
      }) # An open source parametric 3D modeling program
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
      cli-tools
      caps-dual-role
      copy-paste-remaps
      fish
      karabiner
      beekeeper-studio
      libreoffice
      sioyek
    ];
  };
}
