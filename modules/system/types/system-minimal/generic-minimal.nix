{
  # Nix daemon settings shared by every system, regardless of platform.
  flake.modules.generic.system-minimal = {
    nix.settings = {
      experimental-features = ["nix-command" "flakes"];
      # The nr rebuild script evaluates the flake before committing, so a
      # dirty tree is the normal case there, not a mistake worth warning about.
      warn-dirty = false;
    };
  };
}
