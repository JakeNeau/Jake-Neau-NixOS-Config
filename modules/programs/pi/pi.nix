{inputs, ...}: {
  # pi: Mario Zechner's minimal `pi` coding agent, installed truly bare — just
  # the binary. No skills, subagents, MCP, AGENTS.md/RULES.md, extensions, or
  # config policy; pi's config dir (~/.pi/agent) is left for the user to layer
  # home-manager config onto later.
  #
  # The package comes from llm-agents.nix (numtide), which bumps its agents
  # daily and pushes builds to cache.numtide.com, so pi's Rust core is never
  # compiled locally and the pin still moves only with flake.lock.
  # Deliberately NOT `inputs.nixpkgs.follows = "nixpkgs"`: following our
  # nixpkgs would rebuild pi against it and miss the binary cache, which only
  # holds builds against the flake's own pin.
  flake-file.inputs.llm-agents.url = "github:numtide/llm-agents.nix";

  # Per-user install on both platforms, for whichever users list pi in their
  # flake.users.<name>.programs. No HM programs.pi module exists, so the
  # generator supplies the enable toggle and installs pi behind it.
  flake.programs.pi = {
    install.linux = ["home"];
    install.macos = ["home"];
    hasEnableOption = false;
    packages = pkgs: [inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi];
  };

  # Numtide binary cache for the nix daemon. System-scoped, so hosts import
  # this into system config, never homes. The `extra-` prefix appends to the
  # defaults instead of replacing them. Only reaches the daemon at a machine's
  # next system rebuild — a pi home built before that would compile the Rust
  # core from source.
  flake.modules.generic.numtide-cache = {
    nix.settings.extra-substituters = ["https://cache.numtide.com"];
    nix.settings.extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };
}
