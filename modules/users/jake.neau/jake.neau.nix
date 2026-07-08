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
          role-desktop
        ];
      };
    }
  ];
}
