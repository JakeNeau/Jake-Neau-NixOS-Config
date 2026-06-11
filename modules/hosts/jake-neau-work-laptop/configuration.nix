{inputs, ...}: {
  # The macOS work laptop ("jake-neau-work-laptop"). Only the jake.neau user
  # lives here.
  flake.modules.darwin.jake-neau-work-laptop = {pkgs, ...}: {
    imports = [
      inputs.self.modules.darwin.system-desktop
      inputs.self.modules.darwin.podman
      inputs.self.modules.darwin."jake.neau"
      inputs.self.modules.generic.cli
    ];

    networking.hostName = "jake-neau-work-laptop";

    # macOS keyboard behavior
    system.defaults.NSGlobalDomain = {
      InitialKeyRepeat = 15; # delay before repeating a key when holding it down (lower = shorter)
      KeyRepeat = 8; # repeat speed of holding down a key once going (lower = faster)
      ApplePressAndHoldEnabled = false; # turn off accent menu when holding down keys
    };

    # direnv will load nix configs automatically in project folders
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    environment.systemPackages = [
      pkgs.claude-code
      pkgs.getopt # Needed to get some arguments for some bash scripts
    ];

    # Host-specific homebrew casks (the homebrew machinery itself comes from
    # the homebrew feature via system-desktop).
    homebrew.casks = [
      "firefox"
    ];
  };
}
