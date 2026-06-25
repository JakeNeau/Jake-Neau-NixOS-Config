{
  # Claude Code: Anthropic's terminal coding assistant.
  #
  # Cross-platform: nixpkgs builds claude-code on both Linux and macOS, so
  # a single home-manager aspect installs it for the user everywhere it's
  # imported. The nvf editor integration (claudecode.nvim,
  # modules/programs/nvf) spawns this same `claude` CLI.
  #
  # Configuration lives in the user's home folder at its upstream default
  # (~/.claude) — `configDir` is left untouched so the existing config, memory
  # and project history keep working and no CLAUDE_CONFIG_DIR is exported.
  #
  # The extra config (agents/commands/hooks/rules/skills/context) is authored
  # as plain files in ./config and inlined declaratively: each file is read
  # into a string and handed to the module's *content* options (`agents`,
  # `commands`, …). We deliberately avoid the `agentsDir`/`commandsDir`/… "Dir"
  # options because those symlink a whole source directory into ~/.claude; here
  # home-manager instead materialises each file from its text, so the config is
  # shared across machines through the flake rather than via a symlink farm.
  flake.modules.homeManager.claude-code = {
    pkgs,
    lib,
    ...
  }: let
    # Source tree for the declarative config (see ./config/README.md).
    configSrc = ./config;

    # Markdown folders (agents, commands, rules): map each `<name>.md` to
    # { <name> = <file contents> }. `.gitkeep` and any non-markdown file are
    # ignored, so an otherwise-empty folder yields {} (the option default).
    readMarkdown = dir:
      lib.mapAttrs' (
        name: _:
          lib.nameValuePair (lib.removeSuffix ".md" name) (builtins.readFile (dir + "/${name}"))
      ) (lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".md" name) (builtins.readDir dir));

    # Hooks keep their full filename (the module writes hooks/<name> verbatim
    # and marks it executable), so map filename -> contents and skip .gitkeep.
    readHooks = dir:
      lib.mapAttrs (
        name: _: builtins.readFile (dir + "/${name}")
      ) (lib.filterAttrs (name: type: type == "regular" && name != ".gitkeep") (builtins.readDir dir));

    # Each subdirectory of skills/ is one skill; inline its SKILL.md as a
    # string (the module writes skills/<name>/SKILL.md). This single-file form
    # is the trade-off for not symlinking: a skill that ships supporting files
    # alongside SKILL.md would need the directory form instead.
    readSkills = dir:
      lib.mapAttrs (
        name: _: builtins.readFile (dir + "/${name}/SKILL.md")
      ) (lib.filterAttrs (_: type: type == "directory") (builtins.readDir dir));

    # Global context (CLAUDE.md). Empty file -> "" -> nothing is written.
    context = builtins.readFile (configSrc + "/CLAUDE.md");

    # We only want permission prompts for writes: the sandbox runs read-only,
    # no-network commands unprompted; only escaping writes/network still ask.
    settingsPolicy.sandbox = {
      enabled = true;
      autoAllowBashIfSandboxed = true;
    };

    # Force-enable plugins. Claude Code never auto-fetches plugins from settings
    # alone, so each machine's cache is populated once via `claude plugin install
    # <plugin>@claude-plugins-official`; these entries just keep them enabled
    # across rebuilds and machines.
    settingsPolicy.enabledPlugins."superpowers@claude-plugins-official" = true; # skills
    settingsPolicy.enabledPlugins."security-guidance@claude-plugins-official" = true; # in-session vuln review
    settingsPolicy.enabledPlugins."code-simplifier@claude-plugins-official" = false; # disabled: JS/TS-flavored, redundant with comment-simplifier + code-reviewer, fires proactively
    settingsPolicy.enabledPlugins."claude-md-management@claude-plugins-official" = true; # CLAUDE.md audit/maintenance

    # LSP servers mirroring every language nvf configures an LSP for
    # (modules/programs/nvf). Commands are pinned to absolute store paths so
    # the `claude` process always resolves them regardless of PATH.
    lspServers = {
      bash = {
        command = "${pkgs.bash-language-server}/bin/bash-language-server";
        args = ["start"];
        extensionToLanguage = {
          ".sh" = "shellscript";
          ".bash" = "shellscript";
        };
      };
      clang = {
        command = "${pkgs.clang-tools}/bin/clangd";
        args = [];
        extensionToLanguage = {
          ".c" = "c";
          ".h" = "c";
          ".cc" = "cpp";
          ".cpp" = "cpp";
          ".hpp" = "cpp";
        };
      };
      css = {
        command = "${pkgs.vscode-langservers-extracted}/bin/vscode-css-language-server";
        args = ["--stdio"];
        extensionToLanguage = {
          ".css" = "css";
          ".scss" = "scss";
          ".less" = "less";
        };
      };
      dart = {
        command = "${pkgs.dart}/bin/dart";
        args = ["language-server"];
        extensionToLanguage = {".dart" = "dart";};
      };
      go = {
        command = "${pkgs.gopls}/bin/gopls";
        args = [];
        extensionToLanguage = {".go" = "go";};
      };
      html = {
        command = "${pkgs.vscode-langservers-extracted}/bin/vscode-html-language-server";
        args = ["--stdio"];
        extensionToLanguage = {".html" = "html";};
      };
      java = {
        command = "${pkgs.jdt-language-server}/bin/jdtls";
        args = [];
        extensionToLanguage = {".java" = "java";};
      };
      json = {
        command = "${pkgs.vscode-langservers-extracted}/bin/vscode-json-language-server";
        args = ["--stdio"];
        extensionToLanguage = {
          ".json" = "json";
          ".jsonc" = "jsonc";
        };
      };
      lua = {
        command = "${pkgs.lua-language-server}/bin/lua-language-server";
        args = [];
        extensionToLanguage = {".lua" = "lua";};
      };
      markdown = {
        command = "${pkgs.marksman}/bin/marksman";
        args = ["server"];
        extensionToLanguage = {
          ".md" = "markdown";
          ".markdown" = "markdown";
        };
        # marksman reads our [[type:name]] links as wikilinks and flags each as a
        # broken reference, with no per-link escape; disabling diagnostics silences
        # them while keeping navigation/hover.
        diagnostics = false;
      };
      nix = {
        command = "${pkgs.nil}/bin/nil";
        args = [];
        extensionToLanguage = {".nix" = "nix";};
      };
      python = {
        command = "${pkgs.pyright}/bin/pyright-langserver";
        args = ["--stdio"];
        extensionToLanguage = {".py" = "python";};
      };
      rust = {
        command = "${pkgs.rust-analyzer}/bin/rust-analyzer";
        args = [];
        extensionToLanguage = {".rs" = "rust";};
      };
      svelte = {
        command = "${pkgs.svelte-language-server}/bin/svelteserver";
        args = ["--stdio"];
        extensionToLanguage = {".svelte" = "svelte";};
      };
      toml = {
        command = "${pkgs.taplo}/bin/taplo";
        args = ["lsp" "stdio"];
        extensionToLanguage = {".toml" = "toml";};
      };
      typescript = {
        command = "${pkgs.typescript-language-server}/bin/typescript-language-server";
        args = ["--stdio"];
        extensionToLanguage = {
          ".ts" = "typescript";
          ".tsx" = "typescriptreact";
          ".js" = "javascript";
          ".jsx" = "javascriptreact";
          ".mts" = "typescript";
          ".cts" = "typescript";
        };
      };
      yaml = {
        command = "${pkgs.yaml-language-server}/bin/yaml-language-server";
        args = ["--stdio"];
        extensionToLanguage = {
          ".yaml" = "yaml";
          ".yml" = "yaml";
        };
      };
    };
  in {
    programs.claude-code = {
      enable = true;

      # Pull MCP servers declared in `programs.mcp.servers` into Claude Code's
      # config. No-op until that module is enabled with servers; wired here so
      # adding one elsewhere is automatically picked up.
      enableMcpIntegration = true;

      inherit context lspServers;

      # NOTE: settings.json is deliberately NOT managed via the module's
      # `settings` option, which writes a read-only Nix-store symlink — Claude
      # Code mutates that file at runtime (effort level, theme), so that would
      # freeze those knobs. Policy keys are instead merged in at activation
      # (see home.activation.claudeCodeSettingsPolicy below).

      # Declarative config inlined from ./config (see helpers above).
      agents = readMarkdown (configSrc + "/agents");
      commands = readMarkdown (configSrc + "/commands");
      rules = readMarkdown (configSrc + "/rules");
      hooks = readHooks (configSrc + "/hooks");
      skills = readSkills (configSrc + "/skills");
    };

    # MCP servers (flow into Claude via enableMcpIntegration above). mcp-nixos:
    # live search of nixpkgs packages and NixOS/home-manager/nix-darwin options,
    # so Claude looks them up instead of guessing. No credentials needed.
    programs.mcp = {
      enable = true;
      servers.nixos.command = lib.getExe pkgs.mcp-nixos;
    };

    # Merge our policy into the live settings.json rather than owning the file:
    # Claude rewrites it at runtime, so a read-only symlink would freeze theme/effort/hooks.
    home.activation.claudeCodeSettingsPolicy =
      lib.hm.dag.entryAfter ["writeBoundary"] ''
        settings="$HOME/.claude/settings.json"
        mkdir -p "$(dirname "$settings")"
        [ -f "$settings" ] || echo '{}' > "$settings"
        tmp="$(mktemp)"
        ${pkgs.jq}/bin/jq --argjson policy ${lib.escapeShellArg (builtins.toJSON settingsPolicy)} \
          '. * $policy' "$settings" > "$tmp"  # deep-merge, our keys win
        mv "$tmp" "$settings"
      '';

    # keybindings.json, unlike settings.json, is read-only to Claude Code (it
    # never rewrites it), so a declarative Nix-store symlink is safe here.
    # alt+j/k scroll by line and alt+shift+j/k by half page, in both the
    # fullscreen Scroll view and the Ctrl+O Transcript view.
    home.file.".claude/keybindings.json".text = let
      scrollBinds = {
        "alt+k" = "scroll:lineUp";
        "alt+j" = "scroll:lineDown";
        "alt+shift+k" = "scroll:halfPageUp";
        "alt+shift+j" = "scroll:halfPageDown";
      };
    in
      builtins.toJSON {
        "$schema" = "https://www.schemastore.org/claude-code-keybindings.json";
        "$docs" = "https://code.claude.com/docs/en/keybindings";
        bindings = [
          {
            context = "Transcript";
            bindings = scrollBinds;
          }
          {
            context = "Scroll";
            bindings = scrollBinds;
          }
        ];
      };
  };
}
