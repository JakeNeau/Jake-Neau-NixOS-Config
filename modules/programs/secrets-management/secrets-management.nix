{inputs, ...}: {
  # Secret management with sops-nix + age. https://github.com/Mic92/sops-nix
  # Plaintext secrets never live in .nix files; they go in secrets/secrets.yaml.

  flake-file.inputs = {
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  flake.programs.secrets-management = {
    # Per-user everywhere: home-manager-first, and these ship in nixpkgs, so
    # the macOS cask way doesn't apply.
    install.linux = ["home"];
    install.macos = ["home"];
    # No HM programs.secrets-management module exists, so the generator
    # supplies the enable toggle and installs the CLIs behind it.
    hasEnableOption = false;
    packages = pkgs: [
      pkgs.sops # edits and re-encrypts secrets/secrets.yaml
      pkgs.age # the encryption backend those secrets use
    ];
    # The sops-nix wiring below stays hand-written; suppress the nixos class
    # so no generated unit or tombstone collides with it.
    handWritten = ["nixos"];
  };

  # --------------------------------------------
  # NixOS module: decryption at activation
  # --------------------------------------------
  flake.modules.nixos.secrets-management = {
    imports = [inputs.sops-nix.nixosModules.sops];

    sops = {
      # Stays at the repo root, not beside this module: sops finds .sops.yaml
      # by walking up from the cwd, and its rules match `secrets/secrets.yaml$`.
      defaultSopsFile = ../../../secrets/secrets.yaml;
      defaultSopsFormat = "yaml";
      age.keyFile = "/etc/nixos/secrets/keys.txt";
      secrets.hashedPasswordJakeNeau.neededForUsers = true;
    };
  };
}
