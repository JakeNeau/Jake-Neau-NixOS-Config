{inputs, ...}: {
  # The macOS work laptop ("jake-neau-work-laptop"). Only the jake.neau user
  # lives here.
  flake.modules.darwin.jake-neau-work-laptop = {pkgs, ...}: {
    imports = [
      inputs.self.modules.darwin.system-desktop
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

    environment.systemPackages = let
      # Provide a real `docker` binary symlinked to podman, mimicking NixOS's
      # virtualisation.podman.dockerCompat (which is unavailable on darwin).
      docker-podman = pkgs.runCommand "docker-podman" {} ''
        mkdir -p $out/bin
        ln -s ${pkgs.podman}/bin/podman $out/bin/docker
      '';
    in [
      docker-podman # `docker` aliased to podman
      pkgs.claude-code
      pkgs.docker-compose # Provider for podman compose
      pkgs.getopt # Needed to get some arguments for some bash scripts
      pkgs.gvproxy # Network plumbing for native VMs
      pkgs.podman # Daemonless container engine
      pkgs.vfkit # Apple's hypervisor for launching native VMs
    ];

    # Use Apple-native virtualization for `podman machine`.
    environment.variables.CONTAINERS_MACHINE_PROVIDER = "applehv";

    # Host-specific homebrew casks (the homebrew machinery itself comes from
    # the homebrew feature via system-desktop).
    homebrew.casks = [
      "firefox"
    ];
  };
}
