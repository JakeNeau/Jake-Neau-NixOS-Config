{inputs, ...}: {
  # Jake's home environment. The shared desktop config (role-desktop and the
  # global programs) arrives through each host's baseline; only genuinely
  # per-user extras live here.
  flake.modules.homeManager.jakeneau = {
    imports = [inputs.self.modules.homeManager.librewolf];
  };
}
