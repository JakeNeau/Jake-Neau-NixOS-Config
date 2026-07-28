{inputs, ...}: let
  askUserSource = ./extensions/ask-user;
  rustToolsSource = ./extensions/rust-tools;
  workflowSource = ./extensions/workflows;
  writingSource = ./writing;
  mkPiLinkRegistry = pkgs:
    pkgs.runCommand "pi-link-registry.json" {
      nativeBuildInputs = [pkgs.nodejs];
    } ''
      cp -R ${./extensions/typed-links} typed-links
      chmod -R u+w typed-links
      export TEST_SHARED_SKILLS=${../agents-shared/skills}
      export TEST_CLAUDE_SKILLS=${../claude-code/config/skills}
      export TEST_PI_SKILLS=${./config/skills}
      export TEST_PI_COMMANDS=${./config/prompts}
      node --experimental-strip-types --test typed-links/tests/*.test.*
      node ${./extensions/typed-links/registry.mjs} compile-global \
        --skill-root ${../agents-shared/skills} \
        --skill-root ${./config/skills} \
        --command-root ${./config/prompts} \
        --output "$out"
      test -s "$out"
    '';
  codeLldbPath = pkgs: let
    extension = pkgs.vscode-extensions.vadimcn.vscode-lldb;
  in "${extension}/share/vscode/extensions/vadimcn.vscode-lldb/adapter/codelldb";
  rustToolPath = pkgs:
    pkgs.lib.makeBinPath [
      pkgs.cargo
      pkgs.rustc
      pkgs.stdenv.cc
      pkgs.coreutils
    ];
  mkPiAskUserCheck = pkgs:
    pkgs.runCommand "pi-ask-user" {
      nativeBuildInputs = [
        inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi
        pkgs.nodejs
      ];
    } ''
      cp -R ${askUserSource} ask-user
      chmod -R u+w ask-user
      node --experimental-strip-types --test ask-user/tests/*.test.ts

      export HOME="$TMPDIR/home"
      mkdir -p "$HOME"
      printf '{"type":"get_state"}\n' \
        | pi --mode rpc --no-session --offline --no-extensions \
          --extension ./ask-user/index.ts >rpc.jsonl
      grep -q '"success":true' rpc.jsonl
      touch "$out"
    '';
  mkPiWorkflowCheck = pkgs:
    pkgs.runCommand "pi-workflows" {
      nativeBuildInputs = [
        inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi
        pkgs.nodejs
      ];
    } ''
      mkdir extensions
      cp -R ${workflowSource} extensions/workflows
      chmod -R u+w extensions
      node --experimental-strip-types --test extensions/workflows/tests/*.test.ts

      export HOME="$TMPDIR/home"
      mkdir -p "$HOME"
      printf '%s\n' \
        '{"type":"get_state"}' \
        '{"type":"get_commands"}' \
        '{"type":"prompt","message":"/workflow status"}' \
        | pi --mode rpc --no-session --offline --no-extensions \
          --extension ./extensions/workflows/index.ts >rpc.jsonl
      grep -q '"success":true' rpc.jsonl
      grep -q '"name":"refine-spec"' rpc.jsonl

      printf '{"type":"object","properties":{}}\n' >schema.json
      printf '{"catalog":[],"artifacts":{}}\n' >manifest.json
      printf '{"type":"get_state"}\n' \
        | PI_WORKFLOW_CHILD=1 \
          PI_WORKFLOW_SCHEMA="$PWD/schema.json" \
          PI_WORKFLOW_ARTIFACT_MANIFEST="$PWD/manifest.json" \
          PI_WORKFLOW_READ_ONLY=1 \
          PI_WORKFLOW_APPROVED_PATHS='[]' \
          pi --mode rpc --no-session --offline --no-extensions \
            --extension ./extensions/workflows/index.ts >child-rpc.jsonl
      grep -q '"success":true' child-rpc.jsonl
      touch "$out"
    '';
  mkPiRustToolsCheck = pkgs:
    pkgs.runCommand "pi-rust-tools" {
      nativeBuildInputs = [
        pkgs.nodejs
        pkgs.cargo
        pkgs.rustc
        pkgs.rust-analyzer
        pkgs.vscode-extensions.vadimcn.vscode-lldb
        pkgs.stdenv.cc
      ];
    } ''
      cp -R ${rustToolsSource} rust-tools
      chmod -R u+w rust-tools
      export HOME="$TMPDIR/home"
      mkdir -p "$HOME"
      export TEST_CARGO=${pkgs.cargo}/bin/cargo
      export TEST_RUSTC=${pkgs.rustc}/bin/rustc
      export TEST_RUST_ANALYZER=${pkgs.rust-analyzer}/bin/rust-analyzer
      export TEST_CODELLDB=${codeLldbPath pkgs}
      export TEST_NIX=${pkgs.nix}/bin/nix
      node --experimental-strip-types --test rust-tools/tests/*.test.ts
      cat > rust-intelligence.ts <<'EOF'
      import { createRustIntelligence } from "${rustToolsSource}/intelligence.ts";
      export default createRustIntelligence({
        rustAnalyzerPath: "${pkgs.rust-analyzer}/bin/rust-analyzer",
        cargoPath: "${pkgs.cargo}/bin/cargo",
        rustcPath: "${pkgs.rustc}/bin/rustc",
      });
      EOF
      cat > rust-debugger.ts <<'EOF'
      import { createRustDebugger } from "${rustToolsSource}/debugger.ts";
      export default createRustDebugger({
        codeLldbPath: "${codeLldbPath pkgs}",
        cargoPath: "${pkgs.cargo}/bin/cargo",
        rustcPath: "${pkgs.rustc}/bin/rustc",
      });
      EOF
      node --experimental-strip-types --input-type=module - <<'EOF'
      await Promise.all([import("./rust-intelligence.ts"), import("./rust-debugger.ts")]);
      EOF
      touch "$out"
    '';
  mkPiWritingLint = pkgs:
    pkgs.writers.writePython3Bin "pi-writing-lint" {} (
      builtins.readFile (writingSource + "/pi_writing_lint.py")
    );
  mkPiWritingCheck = pkgs:
    pkgs.runCommand "pi-writing" {
      nativeBuildInputs = [pkgs.python3];
    } ''
      cp -R ${writingSource} writing
      chmod -R u+w writing
      PYTHONPATH=writing python3 -m unittest discover -s writing/tests -v
      printf 'The parser reads the file.\n' | ${mkPiWritingLint pkgs}/bin/pi-writing-lint
      touch "$out"
    '';
  mkPiAcp = pkgs:
    pkgs.buildNpmPackage {
      pname = "pi-acp";
      version = inputs.pi-acp.shortRev or "unstable";
      src = inputs.pi-acp;
      npmDeps = pkgs.importNpmLock {npmRoot = inputs.pi-acp;};
      npmConfigHook = pkgs.importNpmLock.npmConfigHook;
      npmBuildScript = "build";
    };
in {
  perSystem = {pkgs, ...}: {
    checks = {
      pi-ask-user = mkPiAskUserCheck pkgs;
      pi-rust-tools = mkPiRustToolsCheck pkgs;
      pi-workflows = mkPiWorkflowCheck pkgs;
      pi-typed-links = mkPiLinkRegistry pkgs;
      pi-writing = mkPiWritingCheck pkgs;
    };
    packages = {
      pi-acp = mkPiAcp pkgs;
      pi-writing-lint = mkPiWritingLint pkgs;
    };
  };

  # Pi itself comes from llm-agents.nix (numtide), whose binary cache avoids a
  # local Rust build. Extension and adapter sources stay immutable in the store.
  flake-file.inputs = {
    llm-agents.url = "github:numtide/llm-agents.nix";
    # Pi exposes RPC but not ACP, so editors need this protocol adapter.
    pi-acp = {
      url = "github:svkozak/pi-acp";
      flake = false;
    };
    pi-agent-browser-native = {
      url = "github:fitchmultz/pi-agent-browser-native/v0.2.71";
      flake = false;
    };
    pi-web-access = {
      url = "github:nicobailon/pi-web-access/v0.13.0";
      flake = false;
    };
  };

  flake.programs.pi = {
    install.linux = ["home"];
    install.macos = ["home"];
    hasEnableOption = false;

    packages = pkgs: let
      system = pkgs.stdenv.hostPlatform.system;
      release = builtins.getAttr system {
        x86_64-linux = {
          name = "linux-x64";
          hash = "sha256-ZmoRKS/xr7KBwCMhL2YguX+BAmy7SY4xTc+vZ+CpKck=";
        };
        aarch64-linux = {
          name = "linux-arm64";
          hash = "sha256-vMJPygfxJ5LjHxbLT7s4iT692cu+lEYxQ5sqVh1yX7w=";
        };
        x86_64-darwin = {
          name = "darwin-x64";
          hash = "sha256-RjD/d8b9vagJ/WKmzOgHhS4PH/qqPmCg/05GkZ9hiMo=";
        };
        aarch64-darwin = {
          name = "darwin-arm64";
          hash = "sha256-uVjIHCmwxr8EB0efk/7549VA6OFYi8QvdqzDP6GpKHo=";
        };
      };
      agent-browser = pkgs.stdenvNoCC.mkDerivation {
        pname = "agent-browser";
        version = "0.32.2";
        src = pkgs.fetchurl {
          url = "https://github.com/vercel-labs/agent-browser/releases/download/v0.32.2/agent-browser-${release.name}";
          inherit (release) hash;
        };
        dontUnpack = true;
        nativeBuildInputs = pkgs.lib.optionals pkgs.stdenv.isLinux [pkgs.autoPatchelfHook];
        buildInputs = pkgs.lib.optionals pkgs.stdenv.isLinux [pkgs.stdenv.cc.cc.lib];
        installPhase = ''
          install -Dm755 "$src" "$out/bin/agent-browser"
        '';
      };
    in [
      inputs.llm-agents.packages.${system}.pi
      inputs.self.packages.${system}.pi-acp
      inputs.self.packages.${system}.pi-writing-lint
      agent-browser
    ];

    config = {
      pkgs,
      lib,
      ...
    }: let
      pi-web-access = pkgs.buildNpmPackage {
        pname = "pi-web-access";
        version = "0.13.0";
        src = inputs.pi-web-access;
        npmDepsHash = "sha256-8onTvv7nUrTXMGvwkMkPEYc+mtpxolzF6Z9EuuB9pbs=";
        postPatch = ''
          cp ${./pi-web-access-package-lock.json} package-lock.json
        '';
        npmInstallFlags = ["--legacy-peer-deps"];
        dontNpmBuild = true;
        dontNpmPrune = true;
      };
      pi-web-access-root = "${pi-web-access}/lib/node_modules/pi-web-access";
      linkRegistry = mkPiLinkRegistry pkgs;
      promptFiles = lib.filterAttrs (
        name: type: type == "regular" && lib.hasSuffix ".md" name
      ) (builtins.readDir ./config/prompts);
      promptHomeFiles =
        lib.mapAttrs' (
          name: _:
            lib.nameValuePair ".pi/agent/prompts/${name}" {
              source = ./config/prompts + "/${name}";
            }
        )
        promptFiles;
      fixedHomeFiles = {
        ".pi/agent/extensions/pi-web-access/index.ts".text = ''
          export { default } from "${pi-web-access-root}/index.ts";
        '';
        ".pi/agent/extensions/pi-agent-browser-native/index.ts".text = ''
          export { default } from "${inputs.pi-agent-browser-native}/extensions/agent-browser/index.ts";
        '';
        ".pi/agent/extensions/ask-user/index.ts".text = ''
          export { default } from "${askUserSource}/index.ts";
        '';
        ".pi/agent/extensions/workflows/index.ts".text = ''
          export { default } from "${workflowSource}/index.ts";
        '';
        ".pi/agent/extensions/typed-links/index.ts".text = ''
          export { default } from "${./extensions/typed-links}/index.ts";
        '';
        ".pi/agent/extensions/rust-intelligence/index.ts".text = ''
          import { createRustIntelligence } from "${rustToolsSource}/intelligence.ts";

          export default createRustIntelligence({
            rustAnalyzerPath: "${pkgs.rust-analyzer}/bin/rust-analyzer",
            cargoPath: "${pkgs.cargo}/bin/cargo",
            rustcPath: "${pkgs.rustc}/bin/rustc",
            nixPath: "${pkgs.nix}/bin/nix",
            toolPath: "${rustToolPath pkgs}",
          });
        '';
        ".pi/agent/extensions/rust-debugger/index.ts".text = ''
          import { createRustDebugger } from "${rustToolsSource}/debugger.ts";

          export default createRustDebugger({
            codeLldbPath: "${codeLldbPath pkgs}",
            cargoPath: "${pkgs.cargo}/bin/cargo",
            rustcPath: "${pkgs.rustc}/bin/rustc",
            nixPath: "${pkgs.nix}/bin/nix",
            toolPath: "${rustToolPath pkgs}",
          });
        '';
        ".pi/agent/skills/pi-web-access".source = "${pi-web-access-root}/skills";
        ".pi/agent/skills/writing-pi-extensions".source = ./config/skills/writing-pi-extensions;
        ".pi/agent/link-registry.json".source = linkRegistry;
        ".pi/agent/keybindings.json".text = builtins.toJSON {
          "app.thinking.cycle" = "ctrl+tab";
        };
        ".pi/agent/AGENTS.md".source = ./config/AGENTS.md;

        # Unattended research should return raw evidence to the main agent, not
        # open the interactive curator or delegate synthesis to another model.
        ".pi/web-search.json".text = builtins.toJSON {
          provider = "exa";
          workflow = "none";
          allowBrowserCookies = false;
        };

        # pi-web-access owns search; the browser extension is the interactive,
        # JavaScript-capable fallback and must not register a duplicate tool.
        ".pi/config/pi-agent-browser-native/config.json".text = builtins.toJSON {
          version = 1;
          webSearch.enabled = false;
        };
      };
    in {
      home.file = fixedHomeFiles // promptHomeFiles;
    };
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
