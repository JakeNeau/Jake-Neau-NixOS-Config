{
  # NixOS runs CUPS with avahi/mDNS so network printers are discovered
  # automatically. macOS ships CUPS + Bonjour natively, so the only knob worth
  # declaring is defaulting the system print dialog to its expanded state.

  # ----------------------------
  # NixOS: CUPS + mDNS discovery
  # ----------------------------
  flake.modules.nixos.printing = {pkgs, ...}: {
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };

    services.printing = {
      enable = true;
      drivers = with pkgs; [
        cups-filters
        cups-browsed
      ];
    };
  };

  # ----------------------------
  # macOS: expanded print dialog
  # ----------------------------
  flake.modules.darwin.printing = {
    system.defaults.NSGlobalDomain = {
      PMPrintingExpandedStateForPrint = true;
      PMPrintingExpandedStateForPrint2 = true;
    };
  };
}
