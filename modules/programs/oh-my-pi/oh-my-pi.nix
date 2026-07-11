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
    config = {
      lib,
      pkgs,
      ...
    }: let
      configSrc = ./config;

      # Portable skills shared with the claude-code module.
      sharedSkillsSrc = ../agents-shared/skills;

      # Map each <name>.md to { <name> = <contents> }, skipping non-markdown
      # (same reader shape as the claude-code module's readMarkdown).
      readMarkdown = dir:
        lib.mapAttrs' (
          name: _:
            lib.nameValuePair (lib.removeSuffix ".md" name) (builtins.readFile (dir + "/${name}"))
        ) (lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".md" name) (builtins.readDir dir));

      # Each subdirectory is one skill; inline its SKILL.md as a string
      # (same reader shape as the claude-code module's readSkills).
      readSkills = dir:
        lib.mapAttrs (
          name: _: builtins.readFile (dir + "/${name}/SKILL.md")
        ) (lib.filterAttrs (_: type: type == "directory") (builtins.readDir dir));

      # Policy keys deep-merged into config.yml at activation (omp rewrites that
      # file at runtime, so it can't be a store symlink — same reasoning as the
      # claude-code settings.json policy). Runtime knobs (color theme, model
      # choice) are deliberately absent so /settings and /model changes survive
      # rebuilds.
      configPolicy = {
        # omp defaults to yolo; always-ask auto-approves read-tier tools only
        # and prompts for write/exec — the conservative non-yolo mode.
        tools.approvalMode = "always-ask";
        # Prefer Anthropic (subscription OAuth via /login) when a canonical
        # model id could resolve to several providers.
        modelProviderOrder = ["anthropic"];
        # Terminals here run a Nerd Font (stylix sets Lilex Nerd Font Mono).
        symbolPreset = "nerd";
      };
    in {
      home.file =
        {
          # Global context, discovered natively by omp (walk-up included).
          ".omp/agent/AGENTS.md".text = builtins.readFile (configSrc + "/AGENTS.md");
          # Sticky rules: omp re-injects these near the current turn, so the
          # hard constraints survive long conversations.
          ".omp/agent/RULES.md".text = builtins.readFile (configSrc + "/RULES.md");

          # MCP servers, mirroring the claude-code module's programs.mcp wiring.
          # omp only writes this file from explicit /mcp config commands, which
          # fail loudly on the read-only symlink — acceptable, since servers are
          # declared here by design.
          ".omp/agent/mcp.json".text = builtins.toJSON {
            "$schema" = "https://raw.githubusercontent.com/can1357/oh-my-pi/main/packages/coding-agent/src/config/mcp-schema.json";
            mcpServers.nixos.command = lib.getExe pkgs.mcp-nixos;
          };
        }
        // lib.mapAttrs' (
          name: text: lib.nameValuePair ".omp/agent/skills/${name}/SKILL.md" {inherit text;}
        ) (readSkills sharedSkillsSrc)
        # Task-agent roster ported from the claude-code agents (omp frontmatter,
        # omp tool names; `task` in tools implies unrestricted spawns).
        // lib.mapAttrs' (
          name: text: lib.nameValuePair ".omp/agent/agents/${name}.md" {inherit text;}
        ) (readMarkdown (configSrc + "/agents"));

      # Merge the policy into the live config.yml rather than owning the file.
      # yq has no --argjson, so the policy is materialised as a store JSON file
      # (JSON is valid YAML) and deep-merged; policy keys win, same semantics
      # as the claude-code jq merge.
      home.activation.ompConfigPolicy = lib.hm.dag.entryAfter ["writeBoundary"] ''
        config="$HOME/.omp/agent/config.yml"
        mkdir -p "$(dirname "$config")"
        [ -f "$config" ] || echo '{}' > "$config"
        tmp="$(mktemp)"
        ${lib.getExe pkgs.yq-go} eval-all -P 'select(fileIndex == 0) * select(fileIndex == 1)' \
          "$config" ${pkgs.writeText "omp-config-policy.json" (builtins.toJSON configPolicy)} > "$tmp"
        mv "$tmp" "$config"
      '';
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
