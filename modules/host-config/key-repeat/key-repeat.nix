{inputs, ...}: {
  # Key-repeat timing, declared once and shared across platforms. macOS applies it
  # now; a niri config can read the same constants later (repeat-delay = delayMs,
  # repeat-rate = 1000 / intervalMs). Values are multiples of 15ms so macOS — which
  # counts InitialKeyRepeat/KeyRepeat in 15ms steps — divides cleanly.
  flake.modules.generic.key-repeat = {lib, ...}: {
    options.keyRepeat = {
      delayMs = lib.mkOption {
        type = lib.types.int;
        default = 225; # delay before a held key starts repeating
        description = "Delay in ms before a held key starts repeating.";
      };
      intervalMs = lib.mkOption {
        type = lib.types.int;
        default = 60; # time between repeats once going (half of cedar's previous 120ms)
        description = "Time in ms between repeats once a key is repeating.";
      };
    };
  };

  flake.modules.darwin.key-repeat = {config, ...}: {
    imports = [inputs.self.modules.generic.key-repeat];
    system.defaults.NSGlobalDomain = {
      InitialKeyRepeat = config.keyRepeat.delayMs / 15; # macOS counts in 15ms steps
      KeyRepeat = config.keyRepeat.intervalMs / 15;
      ApplePressAndHoldEnabled = false; # no accent popup on key-hold
    };
  };
}
