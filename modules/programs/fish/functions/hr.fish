function hr --description "Rebuilds and activates your own home configuration from the system flake"
  set -l flake /etc/nixos
  if test (uname) = Darwin
    set flake /etc/nix-darwin
  end

  # No quotes around the name: home-manager takes everything after '#' raw
  # and quotes it itself (setFlakeAttribute), so caller quotes would corrupt
  # a dotted name like jake.neau.
  # -b backup: standalone home-manager lacks the system module's
  # backupFileExtension, so without it clashing files abort the switch.
  home-manager switch -b backup --flake "$flake#$USER@"(hostname -s)
end
