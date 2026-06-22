{
  # pavucontrol: the sound setting control GUI (pipewire/pulse volume + devices).
  flake.modules.nixos.pavucontrol = {pkgs, ...}: {
    environment.systemPackages = [pkgs.pavucontrol];
  };
}
