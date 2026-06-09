{lib, ...}: {
  # Storage for factory functions that stamp out aspects from parameters.
  # See modules/factory/* for the functions themselves.

  options.flake.factory = lib.mkOption {
    type = lib.types.attrsOf lib.types.unspecified;
    default = {};
  };
}
