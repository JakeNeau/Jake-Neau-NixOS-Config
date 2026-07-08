{inputs, ...}: {
  # The default system type: minimal + the tooling used everywhere.

  flake.modules.nixos.role-default = {
    imports =
      (with inputs.self.modules.nixos; [
        role-minimal
        host-constants
        home-manager
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
        home-manager
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
        yazi
        git
        jujutsu
      ])
      ++ [
        # The hostConstants option declarations; the values are pushed in
        # from the system level (see modules/host-config/host-constants).
        inputs.self.modules.generic.host-constants
      ];
  };
}
