# Chromium extensions

ungoogled-chromium receives every extension from Nix as a local CRX file. A
CRX is a packed and signed extension file. uBlock Origin goes to every host.
Open Claude in Chrome goes to every home that has Claude Code. This page
explains why the design takes that shape. The file-level facts are in the
[feature index](../reference/feature-index.md) and in [the Claude Code
module](../reference/claude-code.md#open-claude-in-chrome).

## Why every extension is a local CRX

ungoogled-chromium never downloads an extension. Its
`disable-webstore-urls.patch` deletes the update check in Chromium's extension
downloader. An update URL, the `ExtensionInstallForcelist` policy, and a
self-hosted update manifest therefore all fail. On macOS a policy force-install
from outside the store also requires MDM (mobile device management)
enrollment, and the Mac is not enrolled.

The browser does accept a local CRX. Each `<id>.json` file in the per-user
`External Extensions` directory names a CRX path (`external_crx`) and its
version (`external_version`). The check that rejects non-store CRX files
compiles only into Google-branded builds. home-manager's
`programs.chromium.extensions` writes these files. With `package = null`, the
module writes only the files and installs no browser.

The mechanism carries three browser rules:

- `external_version` must equal the version in the CRX manifest. The browser
  installs a CRX only when its version is higher than the installed version.
- The signing key sets the extension ID. The ID is the first 32 hex digits of
  the SHA-256 hash of the public key, mapped from `0-f` to `a-p`.
- The browser does not reinstall an external extension that the user removes.
  The user must re-enable it on the extensions page. See [Restore a removed
  extension](../how-to/enable-chromium-extensions.md#restore-a-removed-extension).

## One install mechanism on both platforms

The browser itself stays a system install. nixpkgs builds Chromium only on
Linux, so NixOS installs the nixpkgs package and macOS installs the Homebrew
cask. Both platforms install extensions the same way: a
`programs.chromium.extensions` entry with a `crxPath` in the Nix store.

Linux installs a new external extension silently. macOS installs it disabled,
and the user must click Enable once for each extension. That click is the only
manual step. See [Enable Nix-installed Chromium
extensions](../how-to/enable-chromium-extensions.md).

The rejected alternative was `--load-extension=<dir>` on NixOS. It needs no
signing key. It cannot work for the macOS cask, because the cask has no
wrapper that adds the flag on every launch. One mechanism on both platforms is
simpler.

## ungoogled-chromium as a program declaration

`ungoogled-chromium` is a `flake.programs` declaration with a `"system"` way on
Linux and a `"cask"` way on macOS. Every host lists it in `globalPrograms`.
The host generator routes the system install into the host configuration and
the `-config` unit into every user's baseline. The `-config` unit carries the
extension entries, so each user receives the extension files. The desktop
role no longer imports a hand-written aspect, so the browser has one delivery
channel. See [the declaration framework](declaration-framework.md) for why a
second channel duplicates list entries.

The declaration sets `hasEnableOption = false`. home-manager's module is
`programs.chromium`, not `programs.ungoogled-chromium`. The default would set
`programs.ungoogled-chromium.package`, an option that does not exist. A user
therefore opts out of the browser configuration through `programs.chromium`
(see [per-user opt-out](../reference/generated-units.md#per-user-opt-out)).

## uBlock Origin, the full version

ungoogled-chromium keeps Manifest V2 (MV2) support through an always-on patch,
`extensions-manifestv2.patch`. Full uBlock Origin therefore still runs. A
future Chromium release can remove MV2 code that the patch does not restore.
The fallback is then `chromiumExtensions.ublock-origin-lite`, which is uBlock
Origin Lite.

The CRX comes from the `andre4ik3/nix-browser-addons` flake. Its GitHub
Actions job republishes about 45 Chromium extensions daily as pinned `fetchurl`
derivations. Each derivation carries `version` and `passthru.id`, so the
module hardcodes neither. The module applies the flake's overlay to the home's
own `pkgs`. The flake's `legacyPackages` would instantiate a second nixpkgs.

The addon data lives on the flake's `data` branch. Without an override, the
data stays at the revision that the addons flake locks. A sibling input,
`nix-browser-addons-data`, therefore tracks that branch. The addons input
points `inputs.data.follows` at that sibling. The flake-file tool cannot
override a nested input's `url`, so `follows` is the only route.

Each `nr` updates every input, so it carries new uBlock Origin releases. An
update of `nix-browser-addons` alone does not refresh the data.

The addons input's `nixpkgs` follows this repository's `nixpkgs`. Its own
default is a personal URL, `https://nixpkgs.flake.andre4ik3.dev`.

Two third parties sit between uBlock Origin and the browser:

- One person maintains `nix-browser-addons`.
- `chromiumExtensions.ublock-origin` is the `imputnet/ublock-origin-crx` build.
  imputnet, the Helium browser project, re-signs and publishes it.

The design accepts both. No build step compares the published `version` with
the CRX manifest, so the design also trusts the publisher on that rule.

## Open Claude in Chrome

Open Claude in Chrome lets Claude Code drive the browser. It has three parts:

- the browser extension
- a native messaging host, which the browser starts to connect the extension
  to a local process
- an MCP (Model Context Protocol) server, which Claude Code calls

### Placement is the gate

`modules/programs/claude-code/open-claude-in-chrome.nix` holds every part. It
adds to the claude-code declaration's `config`, so only homes that include
Claude Code evaluate it. Other homes never fetch or build these parts. Today
the one such home is `jake.neau@cedar`.

The parts only add entries to `programs.chromium`. home-manager writes those
entries only where the ungoogled-chromium declaration enables
`programs.chromium`. The browser module never names Claude Code.

The flake input cannot be conditional. Nix reads `inputs` before it evaluates
any configuration, and every host shares one `flake.lock`. Every host
therefore locks the input, and only Claude Code homes use it.

### Tracking upstream main

The source is a non-flake input that tracks upstream `main`. `nr` updates it
with every other input. Upstream code therefore reaches the browser without
review. The design accepts this risk.

Upstream keeps the manifest version at `1.0.0` across code changes. The
browser installs a CRX only when its version is higher, so it would ignore new
code. The build therefore appends a fourth version part. The part is the day
number of the input's `lastModified`, in days since the Unix epoch.

Chromium accepts at most four numeric version parts, each 65535 or lower. The
day number is about 20,700. Evaluation fails with a named message when the
upstream version is not one to three numeric parts. Two upstream revisions
from one day share a version. If `nr` locks the first, the browser receives
the second only with a revision from a later day.

### A committed throwaway signing key

The native messaging host accepts only the extension ID, and the signing key
sets that ID. A stable ID therefore needs a stable key. The repository
commits a dedicated RSA key, `open-claude-in-chrome.pem`, beside the module.
The browser checks the signature against no trusted authority. A copy of the
key lets someone build an extension with the same ID, and nothing more. No
other use may share the key.

The module hardcodes the ID, because Nix strings cannot hold the NUL bytes of
a DER key. The CRX build compares the packed ID with the hardcoded ID and fails
on a mismatch. That check keeps the key, the extension entry, and the native
host's `allowed_origins` in step. The manifest needs no `key` field, because
the browser takes the ID from the CRX signing key.

### Host and server packaging

`buildNpmPackage` builds upstream's `host/` directory with `importNpmLock`.
`importNpmLock` fetches each dependency by its lockfile integrity hash and
needs no `npmDepsHash`. Upstream's lockfile changes with each `nr`, so no hash
needs manual updates.

Upstream's `install.sh` records `$(command -v node)` in the host manifest.
Garbage collection can remove that `node`. The module's wrapper script instead
runs `native-host.js` with a Nix-store `node`, which the home generation keeps
alive. The MCP server runs `mcp-server.js` with the same `node`. The host
writes state only under `~/.config/open-claude-in-chrome/` and the system
temporary directory, so a read-only store path works.

The MCP server reaches Claude Code through `programs.mcp.servers` and
`enableMcpIntegration`, like every other server. See [the declarative
claude-code subsystem](claude-code-config.md).
