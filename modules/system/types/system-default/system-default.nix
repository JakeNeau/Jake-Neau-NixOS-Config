{inputs, ...}: {
  # The default system type: minimal + the tooling used everywhere.

  flake.modules.nixos.system-default = {
    imports = with inputs.self.modules.nixos; [
      system-minimal
      system-constants
      home-manager
      secrets
      nur
      config-group
    ];
  };

  flake.modules.darwin.system-default = {
    imports = with inputs.self.modules.darwin; [
      system-minimal
      system-constants
      home-manager
    ];
  };

  flake.modules.homeManager.system-default = {
    imports =
      (with inputs.self.modules.homeManager; [
        system-minimal
      ])
      ++ [
        # The systemConstants option declarations; the values are pushed in
        # from the system level (see modules/system/system-constants).
        inputs.self.modules.generic.system-constants
      ];
  };
}
