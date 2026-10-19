{ inputs, ... }:
let
  extensionSource = ./extensions;
  askUserSource = "${extensionSource}/ask-user";
  rustToolsSource = "${extensionSource}/rust-tools";
  openPencilSource = "${extensionSource}/openpencil";
  tuneSource = "${extensionSource}/tune";
  workflowSource = "${extensionSource}/workflows";
  statusSource = "${extensionSource}/status";
  writingSource = ./writing;
  mkPiPackage =
    pkgs:
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi.overrideAttrs (old: {
      preInstall = (old.preInstall or "") + ''
        cp -R ${askUserSource} ask-user-tests
        chmod -R u+w ask-user-tests
        node --experimental-strip-types --test ask-user-tests/tests/*.test.ts
      '';
    });
  mkPiLinkRegistry =
    pkgs:
    pkgs.runCommand "pi-link-registry.json"
      {
        nativeBuildInputs = [ pkgs.nodejs ];
      }
      ''
        cp -R ${./extensions/typed-links} typed-links
        chmod -R u+w typed-links
        export TEST_PI_SKILLS=${./config/skills}
        export TEST_PI_COMMANDS=${./config/prompts}
        node --experimental-strip-types --test typed-links/tests/*.test.*
        node ${./extensions/typed-links/registry.mjs} compile-global \
          --skill-root ${./config/skills} \
          --command-root ${./config/prompts} \
          --output "$out"
        test -s "$out"
      '';
  codeLldbPath =
    pkgs:
    let
      extension = pkgs.vscode-extensions.vadimcn.vscode-lldb;
    in
    "${extension}/share/vscode/extensions/vadimcn.vscode-lldb/adapter/codelldb";
  mkPiSettingsUpdater =
    pkgs:
    pkgs.writeShellApplication {
      name = "pi-settings-update";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.jq
      ];
      text = ''
        action="''${1:-}"
        settings="''${2:-}"

        # shellcheck disable=SC2016
        case "$action" in
          set-shell)
            [ "$#" -eq 3 ] || exit 2
            filter='.shellPath = $value'
            ;;
          set-claude-bridge)
            [ "$#" -eq 3 ] || exit 2
            filter='.provider = (.provider // {}) | .provider.pathToClaudeCodeExecutable = $value'
            ;;
          unset-shell)
            [ "$#" -eq 2 ] || exit 2
            filter='del(.shellPath)'
            ;;
          disable-compaction)
            [ "$#" -eq 2 ] || exit 2
            filter='.compaction = (.compaction // {}) | .compaction.enabled = false'
            ;;
          set-usage-bar-thresholds)
            [ "$#" -eq 2 ] || exit 2
            filter='.warningThreshold = 20 | .errorThreshold = 50'
            ;;
          set-tidy-tools)
            [ "$#" -eq 2 ] || exit 2
            filter='.enabled = true | .mode = "default" | .icons = true | .outputReasoning = true'
            ;;
          hide-thinking)
            [ "$#" -eq 2 ] || exit 2
            filter='.hideThinkingBlock = true'
            ;;
          *)
            exit 2
            ;;
        esac

        [ -n "$settings" ] || exit 2
        if [ -L "$settings" ]; then
          echo "refusing to replace symbolic link: $settings" >&2
          exit 1
        fi
        if [ -e "$settings" ] && [ ! -f "$settings" ]; then
          echo "settings path is not a regular file: $settings" >&2
          exit 1
        fi
        if [ "$action" = unset-shell ] && [ ! -e "$settings" ]; then
          exit 0
        fi

        directory="$(dirname "$settings")"
        mkdir -p "$directory"
        temporary="$(mktemp "$directory/.$(basename "$settings").XXXXXX")"
        trap 'rm -f "$temporary"' EXIT

        if [ -e "$settings" ]; then
          jq --arg value "''${3:-}" "$filter" "$settings" > "$temporary"
          chmod --reference="$settings" "$temporary"
        else
          jq -n --arg value "''${3:-}" "{} | $filter" > "$temporary"
          chmod 600 "$temporary"
        fi

        if [ -e "$settings" ] && cmp -s "$settings" "$temporary"; then
          exit 0
        fi

        mv "$temporary" "$settings"
        trap - EXIT
      '';
    };
  rustToolPath =
    pkgs:
    pkgs.lib.makeBinPath [
      pkgs.cargo
      pkgs.rustc
      pkgs.stdenv.cc
      pkgs.coreutils
    ];
  mkPiAskUserCheck =
    pkgs:
    pkgs.runCommand "pi-ask-user"
      {
        nativeBuildInputs = [ (mkPiPackage pkgs) ];
      }
      ''
        cp -R ${askUserSource} ask-user
        chmod -R u+w ask-user

        export HOME="$TMPDIR/home"
        mkdir -p "$HOME"
        printf '{"type":"get_state"}\n' \
          | pi --mode rpc --no-session --offline --no-extensions \
            --extension ./ask-user/index.ts >rpc.jsonl
        grep -q '"success":true' rpc.jsonl
        touch "$out"
      '';
  mkPiTuneCheck =
    pkgs:
    pkgs.runCommand "pi-tune"
      {
        nativeBuildInputs = [
          (mkPiPackage pkgs)
          pkgs.nodejs
        ];
      }
      ''
        cp -R ${tuneSource} tune
        chmod -R u+w tune
        node --experimental-strip-types --test tune/tests/*.test.ts

        export HOME="$TMPDIR/home"
        mkdir -p "$HOME"
        printf '{"type":"get_commands"}\n' \
          | pi --mode rpc --no-session --offline --no-extensions \
            --extension ./tune/index.ts >rpc.jsonl
        grep -q '"name":"tune"' rpc.jsonl
        touch "$out"
      '';
  mkPiStatusCheck =
    pkgs:
    pkgs.runCommand "pi-status"
      {
        nativeBuildInputs = [
          inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi
          pkgs.nodejs
        ];
      }
      ''
        cp -R ${statusSource} status
        chmod -R u+w status
        node --experimental-strip-types --test status/tests/*.test.ts

        export HOME="$TMPDIR/home"
        mkdir -p "$HOME"
        printf '{"type":"get_commands"}\n' \
          | pi --mode rpc --no-session --offline --no-extensions \
            --extension ./status/index.ts >rpc.jsonl
        grep -q '"name":"status"' rpc.jsonl
        touch "$out"
      '';
  mkPiFishShellCheck =
    pkgs:
    pkgs.runCommand "pi-fish-shell"
      {
        nativeBuildInputs = [
          inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi
          pkgs.fish
          pkgs.jq
          pkgs.python3
        ];
      }
      ''
        updater=${mkPiSettingsUpdater pkgs}/bin/pi-settings-update
        settings="$TMPDIR/settings.json"

        printf '{"theme":"light"}\n' > "$settings"
        chmod 640 "$settings"
        "$updater" set-shell "$settings" ${pkgs.fish}/bin/fish
        test "$(jq -r .shellPath "$settings")" = ${pkgs.fish}/bin/fish
        test "$(jq -r .theme "$settings")" = light
        test "$(stat -c %a "$settings")" = 640
        before="$(sha256sum "$settings")"
        "$updater" set-shell "$settings" ${pkgs.fish}/bin/fish
        test "$(sha256sum "$settings")" = "$before"

        bridge="$TMPDIR/claude-bridge.json"
        printf '{"startupNoticeShown":"2026-01-01","provider":{"plan":"max"}}\n' > "$bridge"
        "$updater" set-claude-bridge "$bridge" /nix/store/claude/bin/claude
        test "$(jq -r .provider.pathToClaudeCodeExecutable "$bridge")" = /nix/store/claude/bin/claude
        test "$(jq -r .provider.plan "$bridge")" = max
        test "$(jq -r .startupNoticeShown "$bridge")" = 2026-01-01

        "$updater" unset-shell "$settings"
        test "$(jq -r '.shellPath // "missing"' "$settings")" = missing
        test "$(jq -r .theme "$settings")" = light
        missing="$TMPDIR/missing.json"
        "$updater" unset-shell "$missing"
        test ! -e "$missing"

        malformed="$TMPDIR/malformed.json"
        printf '{broken\n' > "$malformed"
        cp "$malformed" "$malformed.expected"
        if "$updater" set-shell "$malformed" ${pkgs.fish}/bin/fish; then
          exit 1
        fi
        cmp "$malformed" "$malformed.expected"
        if "$updater" disable-compaction "$malformed"; then
          exit 1
        fi
        cmp "$malformed" "$malformed.expected"

        target="$TMPDIR/target.json"
        link="$TMPDIR/link.json"
        printf '{}\n' > "$target"
        ln -s "$target" "$link"
        if "$updater" set-shell "$link" ${pkgs.fish}/bin/fish; then
          exit 1
        fi
        test -L "$link"
        test "$(cat "$target")" = '{}'
        if "$updater" disable-compaction "$link"; then
          exit 1
        fi
        test -L "$link"
        test "$(cat "$target")" = '{}'

        compaction="$TMPDIR/compaction.json"
        printf '{"theme":"light","compaction":{"reserveTokens":16384}}\n' > "$compaction"
        chmod 640 "$compaction"
        "$updater" disable-compaction "$compaction"
        test "$(jq -r .compaction.enabled "$compaction")" = false
        test "$(jq -r .compaction.reserveTokens "$compaction")" = 16384
        test "$(jq -r .theme "$compaction")" = light
        test "$(stat -c %a "$compaction")" = 640
        before="$(sha256sum "$compaction")"
        "$updater" disable-compaction "$compaction"
        test "$(sha256sum "$compaction")" = "$before"

        new_compaction="$TMPDIR/new-compaction.json"
        "$updater" disable-compaction "$new_compaction"
        test "$(jq -c . "$new_compaction")" = '{"compaction":{"enabled":false}}'
        test "$(stat -c %a "$new_compaction")" = 600

        usage_bar="$TMPDIR/usage-bar.json"
        printf '{"segments":["model","context"],"showSecondLine":false,"warningThreshold":70,"errorThreshold":90}\n' > "$usage_bar"
        "$updater" set-usage-bar-thresholds "$usage_bar"
        test "$(jq -r .warningThreshold "$usage_bar")" = 20
        test "$(jq -r .errorThreshold "$usage_bar")" = 50
        test "$(jq -c .segments "$usage_bar")" = '["model","context"]'
        test "$(jq -r .showSecondLine "$usage_bar")" = false

        new_usage_bar="$TMPDIR/agent/pi-usage-bar/config.json"
        "$updater" set-usage-bar-thresholds "$new_usage_bar"
        test "$(jq -c . "$new_usage_bar")" = '{"warningThreshold":20,"errorThreshold":50}'

        tidy_tools="$TMPDIR/tidy-tools.json"
        printf '{"mode":"result","icons":false,"outputReasoning":false,"outputReasoningModel":"fixture"}\n' > "$tidy_tools"
        "$updater" set-tidy-tools "$tidy_tools"
        test "$(jq -r .enabled "$tidy_tools")" = true
        test "$(jq -r .mode "$tidy_tools")" = default
        test "$(jq -r .icons "$tidy_tools")" = true
        test "$(jq -r .outputReasoning "$tidy_tools")" = true
        test "$(jq -r .outputReasoningModel "$tidy_tools")" = fixture
        before="$(sha256sum "$tidy_tools")"
        "$updater" set-tidy-tools "$tidy_tools"
        test "$(sha256sum "$tidy_tools")" = "$before"

        new_tidy_tools="$TMPDIR/agent/pi-tidy-tools.json"
        "$updater" set-tidy-tools "$new_tidy_tools"
        test "$(jq -c . "$new_tidy_tools")" = '{"enabled":true,"mode":"default","icons":true,"outputReasoning":true}'

        thinking="$TMPDIR/thinking.json"
        printf '{"theme":"light","hideThinkingBlock":false}\n' > "$thinking"
        "$updater" hide-thinking "$thinking"
        test "$(jq -r .hideThinkingBlock "$thinking")" = true
        test "$(jq -r .theme "$thinking")" = light
        before="$(sha256sum "$thinking")"
        "$updater" hide-thinking "$thinking"
        test "$(sha256sum "$thinking")" = "$before"

        export HOME="$TMPDIR/home"
        export XDG_CONFIG_HOME="$HOME/.config"
        export PI_CODING_AGENT_DIR="$TMPDIR/pi-agent"
        mkdir -p "$XDG_CONFIG_HOME/fish/functions" "$PI_CODING_AGENT_DIR"
        cat > "$XDG_CONFIG_HOME/fish/functions/pi_fixture.fish" <<'EOF'
        function pi_fixture
            echo fixture-ok
        end
        EOF
        "$updater" set-shell "$PI_CODING_AGENT_DIR/settings.json" ${pkgs.fish}/bin/fish

        python3 - <<'PY'
        import json
        import os
        import subprocess

        process = subprocess.Popen(
            [
                "pi",
                "--mode",
                "rpc",
                "--no-session",
                "--offline",
                "--no-extensions",
                "--no-skills",
                "--no-prompt-templates",
            ],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env=os.environ,
        )

        try:
            for request_id, command, expected in [
                ("syntax", "set value fish-ok; echo $value", "fish-ok\n"),
                ("config", "pi_fixture", "fixture-ok\n"),
            ]:
                process.stdin.write(
                    json.dumps({"id": request_id, "type": "bash", "command": command}) + "\n"
                )
                process.stdin.flush()
                output = ""
                while True:
                    line = process.stdout.readline()
                    if not line:
                        raise RuntimeError(process.stderr.read())
                    message = json.loads(line)
                    if message.get("type") == "bash_execution_update":
                        output += message["delta"]
                    if message.get("type") == "response" and message.get("id") == request_id:
                        if not message.get("success"):
                            raise RuntimeError(message)
                        break
                if output != expected:
                    raise RuntimeError(f"unexpected output for {request_id}: {output!r}")
        finally:
            process.terminate()
            process.wait(timeout=5)
        PY

        touch "$out"
      '';
  mkPiWorkflowCheck =
    pkgs:
    pkgs.runCommand "pi-workflows"
      {
        nativeBuildInputs = [
          inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi
          pkgs.nodejs
        ];
      }
      ''
        mkdir extensions
        cp -R ${askUserSource} extensions/ask-user
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
        grep -q '"name":"refine-plan"' rpc.jsonl

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
  mkPiOpenPencilCheck =
    pkgs:
    pkgs.runCommand "pi-openpencil"
      {
        nativeBuildInputs = [
          inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.pi
          pkgs.nodejs
        ];
      }
      ''
        cp -R ${openPencilSource} openpencil
        chmod -R u+w openpencil
        node --experimental-strip-types --test openpencil/tests/*.test.ts
        cat > openpencil-extension.ts <<'EOF'
        import { createOpenPencilExtension } from "${openPencilSource}/index.ts";
        export default createOpenPencilExtension({ serverPath: "openpencil-mcp" });
        EOF
        export HOME="$TMPDIR/home"
        mkdir -p "$HOME"
        printf '{"type":"get_state"}\n' \
          | pi --mode rpc --no-session --offline --no-extensions \
            --extension ./openpencil-extension.ts >rpc.jsonl
        grep -q '"success":true' rpc.jsonl
        touch "$out"
      '';
  mkPiRustToolsCheck =
    pkgs:
    pkgs.runCommand "pi-rust-tools"
      {
        nativeBuildInputs = [
          pkgs.nodejs
          pkgs.cargo
          pkgs.rustc
          pkgs.rust-analyzer
          pkgs.vscode-extensions.vadimcn.vscode-lldb
          pkgs.stdenv.cc
        ];
      }
      ''
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
  mkPiWritingLint =
    pkgs:
    pkgs.writers.writePython3Bin "pi-writing-lint" { } (
      builtins.readFile (writingSource + "/pi_writing_lint.py")
    );
  mkPiWritingCheck =
    pkgs:
    pkgs.runCommand "pi-writing"
      {
        nativeBuildInputs = [ pkgs.python3 ];
      }
      ''
        cp -R ${writingSource} writing
        chmod -R u+w writing
        PYTHONPATH=writing python3 -m unittest discover -s writing/tests -v
        printf 'The parser reads the file.\n' | ${mkPiWritingLint pkgs}/bin/pi-writing-lint
        touch "$out"
      '';
  npmVersion = src: (builtins.fromJSON (builtins.readFile (src + "/package.json"))).version;
  mkPiClaudeBridge =
    pkgs:
    pkgs.buildNpmPackage {
      pname = "pi-claude-bridge";
      version = npmVersion inputs.pi-claude-bridge;
      src = inputs.pi-claude-bridge;
      npmDeps = pkgs.importNpmLock { npmRoot = inputs.pi-claude-bridge; };
      npmConfigHook = pkgs.importNpmLock.npmConfigHook;
      dontNpmBuild = true;
      postInstall = ''
        package="$out/lib/node_modules/pi-claude-bridge/node_modules"
        rm -rf "$package/@earendil-works" "$package/typebox"
      '';
    };
  # Claude quota uses Pi's Anthropic login instead of a separate Claude Code login.
  # The status also shows when each limit resets.
  mkPiUsageLimits =
    pkgs:
    pkgs.runCommand "pi-usage-limits-${npmVersion inputs.pi-usage-limits}"
      {
        nativeBuildInputs = [ pkgs.nodejs ];
      }
      ''
        # Node refuses type stripping under node_modules, so the tests run before the copy.
        cp -R ${inputs.pi-usage-limits} source
        chmod -R u+w source
        patch -d source -p1 < ${./patches/pi-usage-limits-anthropic-oauth.patch}
        patch -d source -p1 < ${./patches/pi-usage-limits-resets.patch}
        TZ=UTC PI_USAGE_LIMITS_SOURCE="$PWD/source" node --experimental-strip-types \
          --test ${./patches/pi-usage-limits-resets.test.mjs}
        mkdir -p "$out/lib/node_modules"
        cp -R source "$out/lib/node_modules/pi-usage-limits"
      '';
  # The footer gauge tells the user when to start a new session.
  # The second footer line carries the subscription limits status.
  mkPiUsageBar =
    pkgs:
    pkgs.runCommand "pi-usage-bar-${npmVersion inputs.pi-usage-bar}"
      {
        nativeBuildInputs = [ pkgs.nodejs ];
      }
      ''
        # Node refuses type stripping under node_modules, so the source stays at the root.
        cp -R ${inputs.pi-usage-bar} "$out"
        chmod -R u+w "$out"
        patch -d "$out" -p1 < ${./patches/pi-usage-bar-context-warnings.patch}
        patch -d "$out" -p1 < ${./patches/pi-usage-bar-usage-limits.patch}
        PI_USAGE_BAR_SOURCE="$out" node --experimental-strip-types \
          --test ${./patches/pi-usage-bar-context-warnings.test.mjs} \
          ${./patches/pi-usage-bar-usage-limits.test.mjs}
      '';
  mkPiSubagents =
    pkgs:
    let
      package = builtins.removeAttrs (pkgs.lib.importJSON (inputs.pi-subagents + "/package.json")) [
        "devDependencies"
      ];
      lock = pkgs.lib.importJSON (inputs.pi-subagents + "/package-lock.json");
    in
    pkgs.buildNpmPackage {
      pname = "pi-subagents";
      version = package.version;
      src = inputs.pi-subagents;
      npmDeps = pkgs.importNpmLock {
        inherit package;
        packageLock = lock // {
          packages = pkgs.lib.mapAttrs (_: pkg: builtins.removeAttrs pkg [ "devDependencies" ]) (
            pkgs.lib.filterAttrs (_: pkg: !(pkg.dev or false)) lock.packages
          );
        };
      };
      npmConfigHook = pkgs.importNpmLock.npmConfigHook;
      dontNpmBuild = true;
      dontNpmPrune = true;
    };
  mkPiWebAccess =
    pkgs:
    pkgs.buildNpmPackage {
      pname = "pi-web-access";
      version = npmVersion inputs.pi-web-access;
      src = inputs.pi-web-access;
      npmDeps = pkgs.importNpmLock { npmRoot = inputs.pi-web-access; };
      npmConfigHook = pkgs.importNpmLock.npmConfigHook;
      dontNpmBuild = true;
      postInstall = ''
        rm -rf "$out/lib/node_modules/pi-web-access/node_modules"/{@earendil-works,typebox}
      '';
    };
  mkPiAgentBrowserNative =
    pkgs:
    pkgs.buildNpmPackage {
      pname = "pi-agent-browser-native";
      version = npmVersion inputs.pi-agent-browser-native;
      src = inputs.pi-agent-browser-native;
      npmDeps = pkgs.importNpmLock { npmRoot = inputs.pi-agent-browser-native; };
      npmConfigHook = pkgs.importNpmLock.npmConfigHook;
      npmBuildScript = "build";
    };
  # importNpmLock rejects the upstream workspace lockfile, so the published
  # tarball supplies the bundled source and its one runtime dependency.
  mkPiTidyTools =
    pkgs:
    pkgs.runCommand "pi-tidy-tools-${npmVersion inputs.pi-tidy-tools}" { } ''
      root="$out/lib/node_modules/@mobrienv/pi-tidy-tools"
      mkdir -p "$root"
      cp -R ${inputs.pi-tidy-tools}/. "$root"
      chmod -R u+w "$root"
      mkdir -p "$root/node_modules"
      cp -R ${inputs.pi-tidy-tools-semver} "$root/node_modules/semver"
    '';
  mkPiThirdPartyExtensionsCheck =
    pkgs:
    let
      webAccessRoot = "${mkPiWebAccess pkgs}/lib/node_modules/pi-web-access";
      agentBrowserRoot = "${mkPiAgentBrowserNative pkgs}/lib/node_modules/pi-agent-browser-native";
      claudeBridgeRoot = "${mkPiClaudeBridge pkgs}/lib/node_modules/pi-claude-bridge";
      usageLimitsRoot = "${mkPiUsageLimits pkgs}/lib/node_modules/pi-usage-limits";
      subagentsRoot = "${mkPiSubagents pkgs}/lib/node_modules/pi-subagents";
      tidyToolsRoot = "${mkPiTidyTools pkgs}/lib/node_modules/@mobrienv/pi-tidy-tools";
    in
    pkgs.runCommand "pi-third-party-extensions"
      {
        nativeBuildInputs = [ (mkPiPackage pkgs) ];
      }
      ''
        mkdir -p extensions/{web-access,agent-browser,anthropic-auth,usage,usage-bar,usage-limits,claude-bridge,subagents,tidy-tools}
        cat > extensions/web-access/index.ts <<'EOF'
        export { default } from "${webAccessRoot}/index.ts";
        EOF
        cat > extensions/agent-browser/index.ts <<'EOF'
        export { default } from "${agentBrowserRoot}/dist/extensions/agent-browser/index.js";
        EOF
        cat > extensions/anthropic-auth/index.ts <<'EOF'
        export { default } from "${inputs.pi-anthropic-auth}/src/index.ts";
        EOF
        cat > extensions/usage/index.ts <<'EOF'
        export { default } from "${inputs.pi-usage}/extensions/usage/index.ts";
        EOF
        cat > extensions/usage-bar/index.ts <<'EOF'
        export { default } from "${mkPiUsageBar pkgs}/index.ts";
        EOF
        cat > extensions/usage-limits/index.ts <<'EOF'
        export { default } from "${usageLimitsRoot}/index.ts";
        EOF
        cat > extensions/claude-bridge/index.ts <<'EOF'
        export { default } from "${claudeBridgeRoot}/src/index.ts";
        EOF
        cat > extensions/subagents/index.ts <<'EOF'
        export { default } from "${subagentsRoot}/index.ts";
        EOF
        cat > extensions/tidy-tools/index.ts <<'EOF'
        export { default } from "${tidyToolsRoot}/index.ts";
        EOF

        export HOME="$TMPDIR/home"
        mkdir -p "$HOME"
        extension_args=(
          --extension ./extensions/web-access/index.ts
          --extension ./extensions/agent-browser/index.ts
          --extension ./extensions/anthropic-auth/index.ts
          --extension ./extensions/usage/index.ts
          --extension ./extensions/usage-bar/index.ts
          --extension ./extensions/usage-limits/index.ts
          --extension ./extensions/claude-bridge/index.ts
          --extension ./extensions/subagents/index.ts
          --extension ./extensions/tidy-tools/index.ts
        )
        printf '{"type":"get_commands"}\n' \
          | pi --mode rpc --no-session --offline --no-extensions \
            "''${extension_args[@]}" >rpc.jsonl
        grep -q '"name":"websearch"' rpc.jsonl
        grep -q '"name":"anthropic-auth:status"' rpc.jsonl
        grep -q '"name":"usage:1"' rpc.jsonl
        grep -q '"name":"usage:2"' rpc.jsonl
        grep -q '"name":"subagents"' rpc.jsonl
        grep -q '"name":"subagents-doctor"' rpc.jsonl
        grep -q '"name":"subagents-guide"' rpc.jsonl
        grep -q '"name":"tidy"' rpc.jsonl
        grep -q '"name":"diff"' rpc.jsonl
        test -s ${subagentsRoot}/agents/scout.md
        test -s ${subagentsRoot}/agents/worker.md
        test -s ${subagentsRoot}/agents/reviewer.md
        test -s ${subagentsRoot}/skills/pi-subagents/SKILL.md
        test -s ${subagentsRoot}/skills/council-mode/SKILL.md
        test -s ${subagentsRoot}/prompts/parallel-review.md
        test ! -e ${subagentsRoot}/node_modules/@earendil-works
        test ! -e ${subagentsRoot}/node_modules/typebox
        test ! -e ${webAccessRoot}/node_modules/@earendil-works
        test ! -e ${webAccessRoot}/node_modules/typebox
        test ! -e ${tidyToolsRoot}/node_modules/@earendil-works
        test ! -e ${tidyToolsRoot}/node_modules/typebox
        pi --no-session --offline --no-extensions \
          "''${extension_args[@]}" --list-models claude-bridge >models.txt
        grep -q '^claude-bridge ' models.txt
        touch "$out"
      '';
in
{
  perSystem = { pkgs, ... }: {
    checks = {
      pi-ask-user = mkPiAskUserCheck pkgs;
      pi-fish-shell = mkPiFishShellCheck pkgs;
      pi-openpencil = mkPiOpenPencilCheck pkgs;
      pi-rust-tools = mkPiRustToolsCheck pkgs;
      pi-status = mkPiStatusCheck pkgs;
      pi-third-party-extensions = mkPiThirdPartyExtensionsCheck pkgs;
      pi-tune = mkPiTuneCheck pkgs;
      pi-workflows = mkPiWorkflowCheck pkgs;
      pi-typed-links = mkPiLinkRegistry pkgs;
      pi-writing = mkPiWritingCheck pkgs;
    };
    packages = {
      pi-writing-lint = mkPiWritingLint pkgs;
    };
  };

  # Pi comes from llm-agents.nix. The package keeps the cached npm dependencies and builds its Bun executable locally.
  # Extensions track their default branches so `nix flake update` moves them with Pi.
  flake-file.inputs = {
    llm-agents.url = "github:numtide/llm-agents.nix";
    pi-agent-browser-native = {
      url = "github:fitchmultz/pi-agent-browser-native";
      flake = false;
    };
    pi-anthropic-auth = {
      url = "github:gotgenes/pi-anthropic-auth";
      flake = false;
    };
    pi-claude-bridge = {
      url = "github:elidickinson/pi-claude-bridge";
      flake = false;
    };
    pi-subagents = {
      url = "github:nicobailon/pi-subagents";
      flake = false;
    };
    pi-tidy-tools = {
      url = "https://registry.npmjs.org/@mobrienv/pi-tidy-tools/-/pi-tidy-tools-0.5.4.tgz";
      flake = false;
    };
    pi-tidy-tools-semver = {
      url = "https://registry.npmjs.org/semver/-/semver-7.8.5.tgz";
      flake = false;
    };
    pi-usage = {
      url = "github:iefnaf/pi-usage";
      flake = false;
    };
    pi-usage-bar = {
      url = "github:ttiimmaahh/pi-usage-bar";
      flake = false;
    };
    pi-usage-limits = {
      url = "https://registry.npmjs.org/pi-usage-limits/-/pi-usage-limits-0.1.4.tgz";
      flake = false;
    };
    pi-btw = {
      url = "github:dbachelder/pi-btw";
      flake = false;
    };
    pi-web-access = {
      url = "github:nicobailon/pi-web-access";
      flake = false;
    };
  };

  flake.programs.pi = {
    install.linux = [ "home" ];
    install.macos = [ "home" ];
    hasEnableOption = false;

    packages =
      pkgs:
      let
        system = pkgs.stdenv.hostPlatform.system;
      in
      [
        (mkPiPackage pkgs)
        # Pi exposes RPC but not ACP, so editors need this protocol adapter.
        inputs.llm-agents.packages.${system}.pi-acp
        inputs.self.packages.${system}.pi-writing-lint
        inputs.llm-agents.packages.${system}.agent-browser
      ];

    config =
      {
        pkgs,
        lib,
        config,
        ...
      }:
      let
        pi-web-access-root = "${mkPiWebAccess pkgs}/lib/node_modules/pi-web-access";
        pi-agent-browser-native-root = "${mkPiAgentBrowserNative pkgs}/lib/node_modules/pi-agent-browser-native";
        pi-claude-bridge = mkPiClaudeBridge pkgs;
        pi-claude-bridge-root = "${pi-claude-bridge}/lib/node_modules/pi-claude-bridge";
        pi-usage-bar = mkPiUsageBar pkgs;
        pi-usage-limits = mkPiUsageLimits pkgs;
        pi-usage-limits-root = "${pi-usage-limits}/lib/node_modules/pi-usage-limits";
        pi-subagents-root = "${mkPiSubagents pkgs}/lib/node_modules/pi-subagents";
        pi-tidy-tools-root = "${mkPiTidyTools pkgs}/lib/node_modules/@mobrienv/pi-tidy-tools";
        linkRegistry = mkPiLinkRegistry pkgs;
        promptFiles = lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".md" name) (
          builtins.readDir ./config/prompts
        );
        promptHomeFiles = lib.mapAttrs' (
          name: _:
          lib.nameValuePair ".pi/agent/prompts/${name}" {
            source = ./config/prompts + "/${name}";
          }
        ) promptFiles;
        subagentPromptFiles = lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".md" name) (
          builtins.readDir (inputs.pi-subagents + "/prompts")
        );
        subagentPromptHomeFiles = lib.mapAttrs' (
          name: _:
          lib.nameValuePair ".pi/agent/prompts/${name}" {
            source = "${pi-subagents-root}/prompts/${name}";
          }
        ) subagentPromptFiles;
        fishEnabled = config.programs.fish.enable;
        fishShell = "${config.programs.fish.package}/bin/fish";
        settingsUpdater = mkPiSettingsUpdater pkgs;
        homeAssistantMcpEnabled =
          lib.attrByPath [ "programs" "home-assistant" "enableMcpIntegration" ] false config
          && (
            pkgs.stdenv.hostPlatform.isDarwin
            || lib.attrByPath [ "programs" "home-assistant" "enable" ] false config
          );
        homeAssistantFilesystemMcpEnabled = lib.attrByPath [
          "programs"
          "home-assistant-filesystem"
          "enable"
        ] false config;
        homeAssistantMcpFiles = lib.optionalAttrs homeAssistantMcpEnabled {
          ".pi/agent/mcp.json".text = builtins.toJSON {
            mcpServers = {
              "home-assistant" = {
                url = "https://ha.jakeneau.com/api/mcp";
                oauth.clientRegistration = "cimd";
              };
            }
            // lib.optionalAttrs homeAssistantFilesystemMcpEnabled {
              "home-assistant-filesystem" = {
                command = lib.getExe pkgs.mcp-server-filesystem;
                args = [ "/mnt/home-assistant-www" ];
              };
            };
          };
        };
        agentContext =
          builtins.readFile ./config/AGENTS.md
          + lib.optionalString fishEnabled ''

            Pi's `bash` tool runs Fish in this home. Use Fish syntax for every command.
            Do not wrap commands in `fish -c`.
          '';
        fixedHomeFiles = {
          ".pi/agent/extensions/pi-web-access/index.ts".text = ''
            export { default } from "${pi-web-access-root}/index.ts";
          '';
          ".pi/agent/extensions/pi-agent-browser-native/index.ts".text = ''
            export { default } from "${pi-agent-browser-native-root}/dist/extensions/agent-browser/index.js";
          '';
          ".pi/agent/extensions/pi-anthropic-auth/index.ts".text = ''
            export { default } from "${inputs.pi-anthropic-auth}/src/index.ts";
          '';
          ".pi/agent/extensions/pi-usage/index.ts".text = ''
            export { default } from "${inputs.pi-usage}/extensions/usage/index.ts";
          '';
          ".pi/agent/extensions/pi-usage-bar/index.ts".text = ''
            export { default } from "${pi-usage-bar}/index.ts";
          '';
          ".pi/agent/extensions/pi-usage-limits/index.ts".text = ''
            export { default } from "${pi-usage-limits-root}/index.ts";
          '';
          ".pi/agent/extensions/pi-claude-bridge/index.ts".text = ''
            export { default } from "${pi-claude-bridge-root}/src/index.ts";
          '';
          ".pi/agent/extensions/subagent/index.ts".text = ''
            export { default } from "${pi-subagents-root}/index.ts";
          '';
          ".pi/agent/extensions/pi-tidy-tools/index.ts".text = ''
            export { default } from "${pi-tidy-tools-root}/index.ts";
          '';
          ".pi/agent/extensions/pi-btw/index.ts".text = ''
            export { default } from "${inputs.pi-btw}/extensions/btw.ts";
          '';
          ".pi/agent/extensions/status/index.ts".text = ''
            export { default } from "${statusSource}/index.ts";
          '';
          ".pi/agent/extensions/ask-user/index.ts".text = ''
            export { default } from "${askUserSource}/index.ts";
          '';
          ".pi/agent/extensions/openpencil/index.ts".text = ''
            import { createOpenPencilExtension } from "${openPencilSource}/index.ts";

            export default createOpenPencilExtension({
              serverPath: "${config.home.profileDirectory}/bin/openpencil-mcp",
            });
          '';
          ".pi/agent/extensions/tune/index.ts".text = ''
            export { default } from "${tuneSource}/index.ts";
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
          ".pi/agent/skills/brainstorming".source = ./config/skills/brainstorming;
          ".pi/agent/skills/pi-subagents".source = "${pi-subagents-root}/skills/pi-subagents";
          ".pi/agent/skills/council-mode".source = "${pi-subagents-root}/skills/council-mode";
          ".pi/agent/skills/ui-system-initializer".source = ./config/skills/ui-system-initializer;
          ".pi/agent/skills/writing-pi-extensions".source = ./config/skills/writing-pi-extensions;
          ".pi/agent/link-registry.json".source = linkRegistry;
          ".pi/agent/keybindings.json".text = builtins.toJSON {
            "app.thinking.cycle" = "ctrl+shift+l";
            "app.tools.expand" = "alt+o";
          };
          ".pi/agent/AGENTS.md".text = agentContext;

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
      in
      {
        home.file = fixedHomeFiles // promptHomeFiles // subagentPromptHomeFiles // homeAssistantMcpFiles;
        home.activation = {
          piCompaction = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            $DRY_RUN_CMD ${settingsUpdater}/bin/pi-settings-update \
              disable-compaction "$HOME/.pi/agent/settings.json"
          '';
          piUsageBarThresholds = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            $DRY_RUN_CMD ${settingsUpdater}/bin/pi-settings-update \
              set-usage-bar-thresholds "$HOME/.pi/agent/pi-usage-bar/config.json"
          '';
          piTidyTools = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            $DRY_RUN_CMD ${settingsUpdater}/bin/pi-settings-update \
              set-tidy-tools "$HOME/.pi/agent/pi-tidy-tools.json"
          '';
          piHideThinking = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            $DRY_RUN_CMD ${settingsUpdater}/bin/pi-settings-update \
              hide-thinking "$HOME/.pi/agent/settings.json"
          '';
          piClaudeBridgePath = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            $DRY_RUN_CMD ${settingsUpdater}/bin/pi-settings-update \
              set-claude-bridge "$HOME/.pi/agent/claude-bridge.json" \
              ${lib.escapeShellArg (lib.getExe pkgs.claude-code)}
          '';
          piShellPath = lib.hm.dag.entryAfter [ "writeBoundary" ] (
            if fishEnabled then
              ''
                $DRY_RUN_CMD ${settingsUpdater}/bin/pi-settings-update \
                  set-shell "$HOME/.pi/agent/settings.json" ${lib.escapeShellArg fishShell}
              ''
            else
              ''
                $DRY_RUN_CMD ${settingsUpdater}/bin/pi-settings-update \
                  unset-shell "$HOME/.pi/agent/settings.json"
              ''
          );
        };
      };
  };

  # Numtide binary cache for the nix daemon. System-scoped, so hosts import
  # this into system config, never homes. The `extra-` prefix appends to the
  # defaults instead of replacing them. Only reaches the daemon at a machine's
  # next system rebuild — a pi home built before that would compile the Rust
  # core from source.
  flake.modules.generic.numtide-cache = {
    nix.settings.extra-substituters = [ "https://cache.numtide.com" ];
    nix.settings.extra-trusted-public-keys = [
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };
}
