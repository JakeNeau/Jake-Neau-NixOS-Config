{
  # qpwgraph: a pipewire patchbay and volume control.
  flake.modules.nixos.qpwgraph = {pkgs, ...}: {
    environment.systemPackages = [pkgs.qpwgraph];
  };
}
