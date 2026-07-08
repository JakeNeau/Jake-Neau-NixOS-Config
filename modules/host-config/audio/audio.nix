{inputs, ...}: {
  # audio: the system sound stack -- pipewire (with its alsa/pulse/jack bridges)
  # and rtkit, plus the GUI tools needed to operate it. NixOS-only for now; macOS
  # handles sound itself. Sound production/listening apps deliberately live
  # elsewhere -- this is only what's needed for system sound.
  flake.modules.nixos.audio = {
    imports = with inputs.self.modules.nixos; [pavucontrol qpwgraph];

    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };
  };
}
