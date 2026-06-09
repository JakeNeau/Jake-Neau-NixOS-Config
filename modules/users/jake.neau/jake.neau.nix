{
  inputs,
  lib,
  ...
}: {
  # Jake's work user. Lives only on the macOS work laptop. Admin.
  flake.modules = lib.mkMerge [
    (inputs.self.factory.user "jake.neau" true)
    {
      homeManager."jake.neau" = {
        imports = with inputs.self.modules.homeManager; [
          system-desktop
        ];

        programs.git = {
          enable = true;
          settings.user = {
            name = "Jake Neau";
            email = "jakeneau@proton.me";
          };
        };

        programs.jujutsu = {
          enable = true;
          settings.user = {
            name = "Jake Neau";
            email = "jakeneau@proton.me";
          };
        };
      };
    }
  ];
}
