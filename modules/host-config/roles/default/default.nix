{inputs, ...}: {
  # The default system type: minimal + the tooling used everywhere.

  flake.modules.nixos.role-default = {
    imports =
      (with inputs.self.modules.nixos; [
        role-minimal
        host-constants
        secrets
        nur
        config-group
        yazi
        direnv
        git
        printing
      ])
      ++ [inputs.self.modules.generic.network];
  };

  flake.modules.darwin.role-default = {
    imports =
      (with inputs.self.modules.darwin; [
        role-minimal
        host-constants
        nur
        config-group
        manual-workaround
        direnv
        network
        printing
      ])
      ++ [inputs.self.modules.generic.network];
  };

  flake.modules.homeManager.role-default = {
    imports =
      (with inputs.self.modules.homeManager; [
        role-minimal
        git
        jujutsu
      ])
      ++ [
        # The hostConstants option declarations; the values arrive via the
        # hosts generator's read-through of the evaluated system config
        # (see modules/nix/flake-parts/declarations/hosts.nix).
        inputs.self.modules.generic.host-constants
      ];
  };
}
