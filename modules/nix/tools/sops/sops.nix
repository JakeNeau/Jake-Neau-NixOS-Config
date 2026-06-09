{inputs, ...}: {
  # Secret management with sops-nix + age. https://github.com/Mic92/sops-nix
  # Plaintext secrets never live in .nix files; they go in secrets/secrets.yaml.

  flake-file.inputs = {
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  flake.modules.nixos.secrets = {
    imports = [inputs.sops-nix.nixosModules.sops];

    sops = {
      defaultSopsFile = ../../../../secrets/secrets.yaml;
      defaultSopsFormat = "yaml";
      age.keyFile = "/etc/nixos/secrets/keys.txt";
      secrets.hashedPasswordJakeNeau.neededForUsers = true;
    };
  };
}
