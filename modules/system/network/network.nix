{inputs, ...}: {
  # Generic: both NixOS and nix-darwin expose networking.hostName.
  flake.modules.generic.network = {config, ...}: {
    networking.hostName = config.systemConstants.hostName;
  };

  # WiFi via iwd as NetworkManager's backend: iwd drives the radio (IPv6 +
  # auto-connect), NetworkManager manages connections on top.
  flake.modules.nixos.network = {
    networking.wireless.iwd = {
      enable = true;
      settings = {
        IPv6.Enabled = true;
        Settings.AutoConnect = true;
      };
    };

    networking.networkmanager = {
      enable = true;
      wifi.backend = "iwd";
    };
  };
}
