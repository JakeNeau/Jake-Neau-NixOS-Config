{inputs, ...}: {
  # oh-my-pi (omp): batteries-included fork of the `pi` coding agent —
  # subagents, MCP, built-in LSP, skills, plan mode. Installs for whichever
  # users list it in flake.users.<name>.programs (rationale in
  # specs/omp-migration/ until graduation).
  #
  # The package comes from llm-agents.nix (numtide), which bumps its agents
  # daily and pushes builds to cache.numtide.com, so omp's Rust core is never
  # compiled locally and the pin still moves only with flake.lock.
  # Deliberately NOT `inputs.nixpkgs.follows = "nixpkgs"`: following our
  # nixpkgs would rebuild omp against it and miss the binary cache, which only
  # holds builds against the flake's own pin (mac-app-util precedent).
  flake-file.inputs.llm-agents.url = "github:numtide/llm-agents.nix";

  # Per-user install on both platforms. No HM programs.oh-my-pi module exists,
  # so the generator supplies the enable toggle and installs omp behind it
  # (kubernetes precedent).
  flake.programs.oh-my-pi = {
    install.linux = ["home"];
    install.macos = ["home"];
    hasEnableOption = false;
    packages = pkgs: [inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.omp];

    # Declarative ~/.omp/agent in omp's native format (discovery priority 100,
    # so it beats the .claude compat providers, which stay as a safety net).
    # Mirrors the claude-code module's inline-from-./config pattern; auth stays
    # imperative (/login once per machine, tokens in agent.db).
    config = {lib, ...}: let
      configSrc = ./config;

      # Portable skills shared with the claude-code module.
      sharedSkillsSrc = ../agents-shared/skills;

      # Each subdirectory is one skill; inline its SKILL.md as a string
      # (same reader shape as the claude-code module's readSkills).
      readSkills = dir:
        lib.mapAttrs (
          name: _: builtins.readFile (dir + "/${name}/SKILL.md")
        ) (lib.filterAttrs (_: type: type == "directory") (builtins.readDir dir));
    in {
      home.file =
        {
          # Global context, discovered natively by omp (walk-up included).
          ".omp/agent/AGENTS.md".text = builtins.readFile (configSrc + "/AGENTS.md");
          # Sticky rules: omp re-injects these near the current turn, so the
          # hard constraints survive long conversations.
          ".omp/agent/RULES.md".text = builtins.readFile (configSrc + "/RULES.md");
        }
        // lib.mapAttrs' (
          name: text: lib.nameValuePair ".omp/agent/skills/${name}/SKILL.md" {inherit text;}
        ) (readSkills sharedSkillsSrc);
    };
  };

  # Numtide binary cache for the nix daemon. System-scoped, so hosts import
  # this into system config, never homes. The `extra-` prefix appends to the
  # defaults instead of replacing them. Only reaches the daemon at a machine's
  # next system rebuild — an omp home built before that would compile the
  # Rust core from source.
  flake.modules.generic.numtide-cache = {
    nix.settings.extra-substituters = ["https://cache.numtide.com"];
    nix.settings.extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };
}
