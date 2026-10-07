{ inputs, ... }:
{
  # Lets Claude Code drive Chromium: an extension, its native host, and an MCP server.

  # Tracks upstream main; every flake.lock update moves it.
  flake-file.inputs.open-claude-in-chrome = {
    url = "github:noemica-io/open-claude-in-chrome";
    flake = false;
  };

  # Part of claude-code's config, so only homes that import Claude Code get it.
  flake.programs.claude-code.config =
    { pkgs, lib, ... }:
    let
      src = inputs.open-claude-in-chrome;

      # Derived from open-claude-in-chrome.pem, a throwaway key kept only to pin this ID.
      id = "ghpielhenbpoohlpehajamjhhoajejph";
      hostName = "com.anthropic.open_claude_in_chrome";

      # Upstream never bumps its version and Chromium only installs a higher
      # one, so append the input's day number.
      upstreamVersion = (lib.importJSON "${src}/extension/manifest.json").version;
      version =
        assert lib.assertMsg (builtins.match "[0-9]+(\\.[0-9]+){0,2}" upstreamVersion != null)
          "open-claude-in-chrome: upstream version ${upstreamVersion} must be one to three numeric parts so the day count fits as the fourth";
        "${upstreamVersion}.${toString (src.lastModified / 86400)}";

      crx =
        pkgs.runCommand "open-claude-in-chrome-${version}.crx"
          {
            nativeBuildInputs = [
              pkgs.go-crx3
              pkgs.jq
            ];
          }
          ''
            cp -r ${src}/extension .
            chmod -R u+w extension
            jq --arg v ${version} '.version = $v' ${src}/extension/manifest.json > extension/manifest.json
            crx3 pack extension -p ${./open-claude-in-chrome.pem} -o $out
            # The browser takes the ID from the signing key; fail if it drifted.
            [ "$(crx3 id $out)" = ${id} ] || { echo "packed ID $(crx3 id $out) is not ${id}" >&2; exit 1; }
          '';

      host = pkgs.buildNpmPackage {
        pname = "open-claude-in-chrome-host";
        inherit version;
        src = "${src}/host";
        # Fetches by the lockfile's integrity hashes, so input updates need no npmDepsHash.
        npmDeps = pkgs.importNpmLock { npmRoot = "${src}/host"; };
        npmConfigHook = pkgs.importNpmLock.npmConfigHook;
        dontNpmBuild = true;
      };
      hostRoot = "${host}/lib/node_modules/open-claude-in-chrome-host";

      nativeHost = pkgs.writeTextDir "etc/chromium/native-messaging-hosts/${hostName}.json" (
        builtins.toJSON {
          name = hostName;
          description = "Open Claude in Chrome Native Messaging Host";
          # A store-pinned node survives GC, unlike install.sh's `command -v node`.
          path = pkgs.writeShellScript "open-claude-in-chrome-native-host" ''
            exec ${lib.getExe pkgs.nodejs} ${hostRoot}/native-host.js "$@"
          '';
          type = "stdio";
          allowed_origins = [ "chrome-extension://${id}/" ];
        }
      );
    in
    {
      # Inert unless the home enables programs.chromium.
      programs.chromium = {
        extensions = [
          {
            inherit id version;
            crxPath = crx;
          }
        ];
        nativeMessagingHosts = [ nativeHost ];
      };

      # Reaches Claude Code only via programs.claude-code.enableMcpIntegration.
      programs.mcp.servers.open-claude-in-chrome = {
        command = lib.getExe pkgs.nodejs;
        args = [ "${hostRoot}/mcp-server.js" ];
      };
    };
}
