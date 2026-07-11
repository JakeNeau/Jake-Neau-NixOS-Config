{
  # oh-my-pi (omp): batteries-included fork of the `pi` coding agent —
  # subagents, MCP, built-in LSP, skills, plan mode. Replaces Claude Code for
  # the jakeneau user (rationale in specs/omp-migration/ until graduation).
  #
  # The package comes from llm-agents.nix (numtide), which bumps its agents
  # daily and pushes builds to cache.numtide.com, so omp's Rust core is never
  # compiled locally and the pin still moves only with flake.lock.
  flake-file.inputs.llm-agents.url = "github:numtide/llm-agents.nix";
  # Deliberately NOT `inputs.nixpkgs.follows = "nixpkgs"`: following our
  # nixpkgs would rebuild omp against it and miss the binary cache, which only
  # holds builds against the flake's own pin (mac-app-util precedent).

  # Numtide binary cache for the nix daemon, imported by every host's quirks
  # aspect. The `extra-` prefix appends to the defaults instead of replacing
  # them. Only reaches the daemon at each machine's next system rebuild — an
  # omp home built before that would compile the Rust core from source.
  flake.modules.generic.numtide-cache = {
    nix.settings.extra-substituters = ["https://cache.numtide.com"];
    nix.settings.extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };
}
