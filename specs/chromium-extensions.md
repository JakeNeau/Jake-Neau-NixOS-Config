# Chromium extensions

Install browser extensions into ungoogled-chromium declaratively: uBlock Origin
on every machine, and the Open Claude in Chrome extension wherever Claude Code
is installed.

## Spec

### Goal

- Every machine that runs ungoogled-chromium gets uBlock Origin from Nix.
- Every home that runs Claude Code also gets Open Claude in Chrome
  (<https://github.com/noemica-io/open-claude-in-chrome>). This includes the
  extension, its native messaging host, and its MCP server registration.
- No step is manual except the one-time enable click that macOS requires.

### Fixed facts

These facts constrain the design. Each fact was checked against source code on
2026-10-07.

- **The update URL path does not work.** ungoogled-chromium's
  `disable-webstore-urls.patch` deletes the `StartUpdateCheck` loop in
  `ExtensionDownloader::DoStartAllPending`. The browser therefore never
  downloads an extension. This blocks `external_update_url`, the
  `ExtensionInstallForcelist` policy, and self-hosted update manifests.
- **A local CRX does work.** A CRX is a packed and signed extension file. The
  per-user directory `<user data dir>/External Extensions/` accepts
  `<id>.json` files with `external_crx` and `external_version` on Linux and on
  macOS. The rule against non-store CRX files compiles only into
  Google-branded builds (`install_verifier.cc`).
- **home-manager writes these files.** `programs.chromium.extensions` takes
  `{ id; crxPath; version; }` entries. With `package = null` the module writes
  only the JSON files. The files go to `~/.config/chromium/` on Linux and to
  `~/Library/Application Support/Chromium/` on macOS. Both directories match
  ungoogled-chromium.
- **macOS asks once.** Chromium on macOS installs a new external extension
  disabled. The user must click Enable once for each extension. Linux installs
  it silently.
- **Removal is permanent.** If the user removes an external extension in the
  browser, the browser does not reinstall it. The user must re-enable it on
  the extensions page.
- **The version must match.** `external_version` must equal the version in the
  CRX manifest. The browser installs a CRX only when its version is higher
  than the installed version.
- **The signing key sets the ID.** The extension ID is the SHA-256 hash of
  the CRX signing public key: the first 32 hex digits, mapped from 0-f to a-p.
- **Policies do not help on macOS.** The Mac is not enrolled in MDM (mobile
  device management). Chromium therefore blocks policy force-installs from
  outside the store.

### Decision 1: one install mechanism on both platforms

Both extensions use `programs.chromium.extensions` with a `crxPath` in the
Nix store and `package = null`. The browser itself stays installed as it is
today: the `ungoogled-chromium` system package on NixOS and the Homebrew cask
on macOS.

Rejected alternative: `--load-extension=<dir>` on NixOS. It needs no signing
key. It cannot work for the macOS cask, because the cask has no wrapper to add
the flag on every launch. One mechanism everywhere is simpler.

### Decision 2: uBlock Origin, full version

ungoogled-chromium keeps Manifest V2 (MV2) support through an always-on patch,
`extensions-manifestv2.patch`. Full uBlock Origin therefore still runs.

- Source: the signed CRX from the gorhill/uBlock GitHub release, fetched with
  `pkgs.fetchurl` and pinned by version and hash.
- ID: `fkgkibajhfbepljeaefdnfnegdcjomkh`. This ID belongs to the GitHub CRX
  signing key. The Chrome Web Store ID `cjpalhdlnbpafiamejdnhcphjbkeiagm` is
  wrong for this CRX.
- Updates: the user bumps the version and hash by hand.
- Fallback: if a future Chromium release removes the MV2 code beyond what the
  patch restores, switch to uBlock Origin Lite. Its ID is
  `ddkjiahejlhfcafbddmgiahcphecmpfh`, and it ships no CRX release.

### Decision 3: Open Claude in Chrome lives in the claude-code module

Every Open Claude in Chrome part goes in `modules/programs/claude-code/`:

- the flake input
- the packed CRX
- the native messaging host
- the MCP server

Placement is the gate. A home evaluates these parts only when it includes
Claude Code, so other machines never fetch or build them. The parts only add
entries to `programs.chromium`. home-manager therefore writes them only where
the chromium module enables `programs.chromium`. The browser module never
names Claude Code.

A flake input cannot be conditional. Nix reads `inputs` before it evaluates
any configuration, and every machine shares one `flake.lock`.

### Decision 4: the source tracks main through a flake input

At the user's choice, the source is a non-flake input,
`github:noemica-io/open-claude-in-chrome` with `flake = false`. `nr` updates it
with every other input. Upstream code therefore reaches the browser without
review. The user accepted this risk.

The upstream manifest version stays at `1.0.0` across code changes. A pinned
version would make the browser ignore new code. The build therefore rewrites
the manifest version, and `external_version` uses the same value. The new
version is `<upstream version>.<days since the epoch of the input's
lastModified>`. Chromium accepts at most four numeric parts, each 65535 or
lower, and the day count is about 20,700. Limit: two upstream updates on one
day reach the browser only after a later update.

### Decision 5: a committed throwaway signing key

At the user's choice, a dedicated RSA key lives in the repo next to the
module. The key exists only to keep the extension ID stable. The browser
checks no signature against a trusted authority. A copy of the key lets
someone build an extension with the same ID, and nothing more. The key must
never be reused.

The ID is computed once and hardcoded, because Nix strings cannot hold the NUL
bytes of a DER key. A build-time check compares the ID of the packed CRX with
the hardcoded ID. The CRX does not need a `key` field in its manifest, because
the browser takes the ID from the CRX signing key.

### Decision 6: the full Open Claude in Chrome setup

- **The host package.** One derivation holds `host/` with its npm
  dependencies. Its lockfile changes when `nr` updates the input. The build
  therefore uses `pkgs.importNpmLock`, which fetches each package by its
  lockfile integrity hash and needs no `npmDepsHash`. The package includes
  only the default server, `host/mcp-server.js`, which has 21 tools. The
  codemode and hybrid servers need `wrangler` and a Cloudflare Worker, so the
  package excludes them.
- **The native messaging host.** Name: `com.anthropic.open_claude_in_chrome`.
  A wrapper script runs `native-host.js` with a Nix-store `node`. The upstream
  `install.sh` instead records `$(command -v node)`, which garbage collection
  can remove. The host manifest lists `chrome-extension://<id>/` in
  `allowed_origins`. The manifest reaches the browser through
  `programs.chromium.nativeMessagingHosts` as a package that holds
  `etc/chromium/native-messaging-hosts/<name>.json` as a real file.
- **The MCP server.** `programs.mcp.servers.open-claude-in-chrome` runs
  `mcp-server.js` with the same `node`. `enableMcpIntegration` already passes
  `programs.mcp` servers to Claude Code.
- **Writable state.** The host writes only under `~/.config/open-claude-in-chrome/`
  and `os.tmpdir()`, so a read-only store path works.

### Decision 7: ungoogled-chromium becomes a program declaration

`modules/programs/ungoogled-chromium/ungoogled-chromium.nix` becomes
`flake.programs.ungoogled-chromium`, modeled on `ghostty`:

- `install.linux = [ "system" ]` and `install.macos = [ "cask" ]`
- a home-manager `config` that sets `programs.chromium` with `enable = true`,
  `package = null`, and the uBlock Origin entry

All four hosts list `ungoogled-chromium` in `globalPrograms`. The NixOS and
darwin `role-desktop` aspects stop importing the hand-written aspect.
`desktop.nix` has uncommitted edits from other work, and the change must keep
them.

### Risks

- **macOS CRX support is unconfirmed in practice.** The source code supports
  it, but no field report confirms it on ungoogled-chromium for macOS. The
  first rebuild on cedar is the test.
- **A version bump may prompt again on macOS.** This is unverified.
- **The MV2 patch has no guaranteed lifetime.** See the fallback in
  Decision 2.
- **Unreviewed upstream code.** This is accepted in Decision 4.

### Validation

- `nix flake check`
- `nix build .#darwinConfigurations.cedar.system --no-link` and the same for
  `aspen`
- `nix build '.#homeConfigurations."jake.neau@cedar".activationPackage' --no-link`
  and the same for `jakeneau@aspen`
- Evaluate the `drvPath` of the NixOS hosts `redwood` and `spruce` and of
  their homes.
- Check that `jakeneau@aspen` evaluates no Open Claude in Chrome derivation.
- The user runs `hr` on cedar and confirms the following:
  - both extensions appear
  - each extension enables with one click
  - `/mcp` lists `open-claude-in-chrome`
  - a browser tool call succeeds
