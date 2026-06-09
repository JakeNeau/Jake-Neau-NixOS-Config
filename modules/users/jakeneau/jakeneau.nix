{
  inputs,
  lib,
  ...
}: {
  # Jake's personal user. Lives on the NixOS desktop + laptop and the personal
  # MacBook. Admin everywhere.
  flake.modules = lib.mkMerge [
    (inputs.self.factory.user "jakeneau" true)
    {
      # NixOS-only extras: description + sops-managed password.
      nixos.jakeneau = {config, ...}: {
        users.users.jakeneau = {
          description = "Jake Neau";
          hashedPasswordFile = config.sops.secrets.hashedPasswordJakeNeau.path;
        };
      };
    }
  ];
}
