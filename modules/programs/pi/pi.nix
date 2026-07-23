{inputs, ...}: let
  mkPiLinkRegistry = pkgs:
    pkgs.runCommand "pi-link-registry.json" {
      nativeBuildInputs = [pkgs.nodejs];
    } ''
      cp -R ${./extensions/typed-links} typed-links
      chmod -R u+w typed-links
      node --experimental-strip-types --test typed-links/tests/*.test.*
      node ${./extensions/typed-links/registry.mjs} compile-global \
        --skill-root ${../agents-shared/skills} \
        --skill-root ${./config/skills} \
        --command-root ${./config/prompts} \
        --output "$out"
      test -s "$out"
    '';
  mkPiAcp = pkgs:
    pkgs.buildNpmPackage {
      pname = "pi-acp";
      version = inputs.pi-acp.shortRev or "unstable";
      src = inputs.pi-acp;
      npmDepsHash = "sha256-qN+b/tMbnJLkWjotl3XrA0nfZ3KT/mT6gM+n3Qiz8Wk=";
      npmBuildScript = "build";
    };
in {
  perSystem = {pkgs, ...}: {
    checks.pi-typed-links = mkPiLinkRegistry pkgs;
    packages.pi-acp = mkPiAcp pkgs;
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
        ".pi/agent/extensions/typed-links/index.ts".text = ''
          export { default } from "${./extensions/typed-links}/index.ts";
        '';
        ".pi/agent/skills/pi-web-access".source = "${pi-web-access-root}/skills";
        ".pi/agent/skills/writing-pi-extensions".source = ./config/skills/writing-pi-extensions;
        ".pi/agent/link-registry.json".source = linkRegistry;
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
