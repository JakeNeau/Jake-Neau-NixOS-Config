{inputs, ...}: {
  flake.modules.nixos.graphics = {
    imports = with inputs.self.modules.nixos; [graphics-amd graphics-intel graphics-nvidia];
    hardware.graphics = {
      enable = true;
      enable32Bit = true; # 32-bit GPU drivers for 32-bit apps (e.g. Wine)
    };
  };
  flake.modules.darwin.graphics = {
    imports = [inputs.self.modules.darwin.graphics-apple];
  };
}
