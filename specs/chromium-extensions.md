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

These facts constrain the design. Research agents checked each fact against source code
on 2026-10-07.

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

- Source: the `andre4ik3/nix-browser-addons` flake, at the user's choice. Its
  GitHub Actions job republishes about 45 Chromium extensions daily as pinned
  `fetchurl` derivations, with `version` and `passthru.id` attributes. Each
  `nr` therefore carries new uBlock Origin releases, so no step is manual.
- Package: `chromiumExtensions.ublock-origin`. It is the
  `imputnet/ublock-origin-crx` build, a re-signed copy of uBlock Origin that
  imputnet (the Helium browser project) publishes. The user accepted this
  third party.
- ID: `blockjmkbacgjkknlgpkjjiijinjdanf`, taken from `passthru.id`, never
  hardcoded.
- Input wiring: the addon data lives on the flake's `data` branch. A sibling
  input, `nix-browser-addons-data` (`github:andre4ik3/nix-browser-addons/data`,
  `flake = false`), tracks that branch, and the addons input sets
  `inputs.data.follows` to it. Otherwise the data stays frozen at the flake's
  own lock. flake-file cannot override a nested `url`, so `follows` is the
  only route. The input's `nixpkgs` must follow this repo's `nixpkgs`,
  because its default is a personal URL, `https://nixpkgs.flake.andre4ik3.dev`.
- Fallback: if a future Chromium release removes the MV2 code beyond what the
  patch restores, switch to `chromiumExtensions.ublock-origin-lite`, which is
  uBlock Origin Lite (ID `ddkjiahejlhfcafbddmgiahcphecmpfh`).

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

The plan computes the ID once and hardcodes it, because Nix strings cannot hold the NUL
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

### Risks

- **macOS CRX support is unconfirmed in practice.** The source code supports
  it, but no field report confirms it on ungoogled-chromium for macOS. The
  first rebuild on cedar is the test.
- **A version bump may prompt again on macOS.** No source confirms or rules this out.
- **The MV2 patch has no guaranteed lifetime.** See the fallback in
  Decision 2.
- **Unreviewed upstream code.** The user accepted this risk in
  Decision 4.
- **Two third parties sit between uBlock Origin and the browser.** One person
  maintains nix-browser-addons, and imputnet signs the CRX. The user accepted
  this in Decision 2.

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

## Plan

**Goal:** Install uBlock Origin into ungoogled-chromium on all four hosts. Also
install Open Claude in Chrome into every home that has Claude Code. Its parts
are the extension, its native messaging host, and its MCP server, all from Nix.

**Architecture:** `ungoogled-chromium` becomes a `flake.programs` declaration.
Its generated system units keep today's installs. Its `-config` unit enables
home-manager's `programs.chromium` with `package = null` and the uBlock Origin
CRX from the `nix-browser-addons` overlay. A new file in the claude-code folder
adds to `flake.programs.claude-code.config`. It builds a signed CRX from a
non-flake input and packages `host/` with `importNpmLock`. It then appends
entries to `programs.chromium.extensions`,
`programs.chromium.nativeMessagingHosts`, and `programs.mcp.servers`.

**Tech stack:** Nix flake (flake-parts, flake-file, import-tree), home-manager
`programs.chromium` and `programs.mcp`, the `andre4ik3/nix-browser-addons`
overlay, `buildNpmPackage` + `importNpmLock`, `go-crx3` (CLI `crx3`), `jq`,
`nodejs`, and LibreSSL `openssl` (macOS `/usr/bin/openssl`).

**Departure from the Spec, for the user to accept at plan review:** Decision 2
says to override `inputs.data.url`. flake-file cannot declare a nested `url`.
The plan therefore adds a sibling root input, `nix-browser-addons-data`, and
sets `inputs.data.follows` to it. The effect is the same: the data tracks the
`data` branch, and `nr`'s full `nix flake update` refreshes it. One difference
remains: a per-input `nix flake update nix-browser-addons` alone would not
refresh the data.

**Global constraints:**

- Reuse the existing idioms named below, and add no other pattern.
- Never hand-edit `flake.nix`. Declare inputs in `flake-file.inputs`, run
  `nix run .#write-flake`, then `nix flake lock`. Never run `nix flake update`
  (full or per-input), `switch`, `hr`, `nr`, or `nrr`.
- `git add` every new file before any evaluation. Flake evaluation ignores
  untracked files.
- `nix` commands need the sandbox disabled here, because the sandbox blocks the
  daemon socket and `~/.cache/nix`. Always pass `--no-link`. The Mac cannot
  build NixOS outputs, so evaluate their `drvPath` instead.
- Format touched `.nix` files with `nix fmt -- <files>` (nixfmt-tree). Never
  format the whole tree.
- Edit `desktop.nix` with two targeted line removals. Never rewrite the file.
- Each shell command block starts a fresh shell (zsh on this machine, which
  does not word-split unquoted variables). Every block derives what it needs
  itself.
- uBlock Origin's ID comes from `passthru.id` (`blockjmkbacgjkknlgpkjjiijinjdanf`
  today). Never hardcode it.
- Native host name `com.anthropic.open_claude_in_chrome`. MCP server name
  `open-claude-in-chrome`.
- Open Claude in Chrome version: `<upstream manifest version>.<input
  lastModified / 86400>`. Both the CRX manifest and `external_version` use it.

**Files:**

- `modules/programs/ungoogled-chromium/ungoogled-chromium.nix` (rewrite): the
  `nix-browser-addons` inputs, the `flake.programs.ungoogled-chromium`
  declaration, and the uBlock Origin extension.
- `modules/host-config/roles/desktop/desktop.nix` (modify): drop
  `ungoogled-chromium` from `flake.modules.nixos.role-desktop` and
  `flake.modules.darwin.role-desktop` imports.
- `modules/hosts/{cedar,aspen,redwood,spruce}/configuration.nix` (modify): add
  `"ungoogled-chromium"` to each `globalPrograms`.
- `modules/programs/claude-code/open-claude-in-chrome.nix` (create): the flake
  input and every Open Claude in Chrome part.
- `modules/programs/claude-code/open-claude-in-chrome.pem` (create): the
  throwaway PKCS#8 RSA signing key.
- `flake.nix` and `flake.lock` (regenerated, never hand-edited): Task 1 adds the
  two browser-addons inputs, and Task 2 adds `open-claude-in-chrome`.

**Facts the plan rests on** (verified 2026-10-07):

- `modules/nix/flake-parts/declarations/programs.nix`:
  - `config` is `types.deferredModule`. A second file can therefore add to
    `flake.programs.claude-code.config`, and both definitions merge.
  - The generated `nixos.<name>` unit is
    `environment.systemPackages = [ pkgs.<name> ]`. The generated
    `darwin.<name>` unit is `homebrew.casks = [ <name> ]`. Both match today's
    hand-written aspect exactly.
  - With the default `hasEnableOption = true` and a system or cask way, the
    `-config` unit sets `programs.<name>.package = null`. home-manager has no
    `programs.ungoogled-chromium`, so the declaration sets
    `hasEnableOption = false`, as `windows-app.nix` and `onedrive.nix` do.
    `-config` is then the plain `config`.
- `modules/nix/flake-parts/declarations/hosts.nix`:
  - `wayOf` resolves a global program with no `"home"` way to its sole system
    way: `"system"` on NixOS and `"cask"` on darwin.
  - `systemUnits` routes the system half into `<host>-host-config`.
    `baselineUnits` routes `homeManager.<name>-config` into the baseline.
  - `wrapValue` leaves lists unstamped. The `extensions` and
    `nativeMessagingHosts` lists from both files therefore concatenate.
- Locked home-manager `modules/programs/chromium.nix`:
  - `package` is `nullOr package`, and `null` installs nothing.
  - `extensions` is a list of `{ id (strMatching "[a-zA-Z]{32}"); updateUrl; crxPath (nullOr path); version (nullOr str); }`.
  - With `crxPath` set, `extensionJson` writes
    `<configDir>/External Extensions/<id>.json` =
    `{ external_crx; external_version; }`.
  - `nativeMessagingHosts` is a list of packages, symlink-joined. HM links
    `<joined>/etc/chromium/native-messaging-hosts` recursively to
    `<configDir>/NativeMessagingHosts`.
  - With `package = null`, `configDir` is `Library/Application Support/Chromium`
    on darwin. On Linux it is `${xdg.configHome}/chromium`, which gives the
    NixOS homes the absolute `home.file` key `/home/jakeneau/.config/chromium`.
- Locked home-manager `modules/programs/mcp.nix`: a server is
  `{ command (nullOr str); args (listOf str); env; url; ... }`.
  `claude-code.nix` already sets `enableMcpIntegration = true` and
  `programs.mcp.enable = true`. The current servers are `clickup` and `nixos`.
- `andre4ik3/nix-browser-addons`:
  - Its `flake.nix` inputs are `nixpkgs` (`https://nixpkgs.flake.andre4ik3.dev`),
    `data` (`github:andre4ik3/nix-browser-addons/data`, `flake = false`), and
    `treefmt` (whose `nixpkgs` follows the flake's own `nixpkgs`).
  - `overlays.default` is `import ./overlay.nix data`. The overlay reads only
    `final.lib` and `final.fetchurl`.
  - `chromiumExtensions.<name>` is `fetchurl { name = "<pname>-<version>.crx"; inherit (addon) version passthru; inherit (addon.file) url hash; }`.
  - On the `data` branch (2026-10-07), `ublock-origin` is version `1.75.0`,
    `passthru.id` `blockjmkbacgjkknlgpkjjiijinjdanf`, from
    `https://github.com/imputnet/ublock-origin-crx/releases/download/1.75.0/uBlock0_1.75.0.crx`.
    `crx3 id` of the fetched file gives the same ID.
- flake-file's nested `inputs.<name>.inputs.<sub>` option accepts only
  `follows`, `inputs`, and `autoFollow`, with no `url`. The data-branch override
  is therefore a sibling root input, `nix-browser-addons-data`, plus
  `inputs.data.follows`. The effect equals Decision 2's `inputs.data.url`.
  write-flake renders it as
  `inputs = { data.follows = "nix-browser-addons-data"; nixpkgs.follows = "nixpkgs"; };`.
- This repo's root nixpkgs input carries the name `nixpkgs`
  (`github:NixOS/nixpkgs/nixos-unstable`). Its lock node is `nixpkgs_6`.
- Applying the overlay to the home's own `pkgs`, as in
  `(inputs.nix-browser-addons.overlays.default pkgs pkgs)`, avoids a second
  nixpkgs instance. The input's `legacyPackages` instead builds on
  `nixpkgs.legacyPackages.<system>`, a separate, unconfigured instance. Both
  give the same store path. On the cedar home's uBlock Origin JSON, the
  overlay cost 2.10 M thunks against 2.34 M for `legacyPackages`.
- `nix flake lock` after Task 1's write-flake adds exactly the
  `nix-browser-addons`, `nix-browser-addons-data`, and `treefmt` nodes and their
  two root entries. It changes no existing node (64 inserted lines, none
  deleted). `treefmt`'s `nixpkgs` follows `nix-browser-addons/nixpkgs`, which
  follows the root `nixpkgs`. The `treefmt` node is locked but never evaluated,
  because the overlay does not touch it.
- write-flake does not lock, because flake-file's `auto-follow` is off here.
- Locked nixpkgs (`f45c6f04`):
  - It ships `go-crx3` 1.7.0 (`bin/crx3`), `nodejs` 24.21.0, `importNpmLock`,
    and `importNpmLock.npmConfigHook`.
  - `pi.nix`'s `mkPiAcp` is the precedent for `importNpmLock` with a flake
    input.
  - `buildNpmPackage` runs `npm run build` unless `dontNpmBuild = true`.
    Upstream `host/package.json` has no build script.
- `crx3 pack <dir> -p <pem> -o <file>` and `crx3 id <file.crx>` work with a
  PKCS#8 key and with `HOME` unset or nonexistent. They leave the source
  directory untouched. `crx3 id` prints the 32-letter ID. That ID equals
  `openssl pkey -pubout -outform DER | sha256 | first 32 hex | tr 0-9a-f a-p`.
- Upstream Open Claude in Chrome (`6a37c29`):
  - `extension/manifest.json` is MV3 with version `"1.0.0"` and no `key`.
  - `host/` has its own `package-lock.json` (lockfileVersion 3, all registry
    tarballs).
  - The entry points `mcp-server.js` and `native-host.js` import only
    `./endpoint.js`, `./tool-runtime.js`, `./tool-definitions.js`, and
    `./parent-watch.js`.
  - `parent-watch.js` calls `execFile("powershell")` only on `win32`, so
    neither wrapper needs a `PATH`.
  - The host writes only under `~/.config/open-claude-in-chrome/` and
    `os.tmpdir()`.
- An end-to-end run of this whole plan in a scratch clone of HEAD passed:
  - every probe
  - both macOS systems and both macOS homes
  - the ID-mismatch test
  - the MCP smoke test (26 tools at `6a37c29`)
  - the four NixOS `drvPath` evaluations
  - the gate check
  - `nix flake check`
- `builtins.toJSON` renders a derivation as its store path.

**Edge cases and invariants:**

- `external_version` must equal the packed manifest version. For Open Claude in
  Chrome both come from the one `version` binding, and the build packs that
  version. For uBlock Origin the plan trusts the publisher. The data JSON's
  `version` comes from imputnet's `update.xml`, and no build step checks it
  against the CRX. Both read `1.75.0` today.
- Chromium allows at most four numeric version parts. An upstream version with
  four parts leaves no room for the day count. Evaluation then fails through
  `assertMsg` rather than shipping an uninstallable CRX.
- The CRX's signing key must produce the hardcoded `id`. The CRX build fails
  when `crx3 id` disagrees. That keeps the key, the extension entry, and the
  native host's `allowed_origins` in step.
- Gating: every Open Claude in Chrome derivation sits inside the claude-code
  `config` function. Only homes that import a claude-code unit evaluate it,
  which today means `jake.neau@cedar` alone. The entries stay inert where
  `programs.chromium.enable` is false.
- Data tracking: without the `inputs.data.follows` override, uBlock Origin
  would stay at the data revision in the addons flake's own lock. `nr` updates
  `nix-browser-addons-data` with every other input.
- Each `nix flake lock` must add only that task's new nodes and change no
  existing node.
- The committed PEM and `nr`'s push: GitHub push protection for personal public
  repositories blocks only provider patterns by default. It blocks the generic
  `-----BEGIN PRIVATE KEY-----` pattern only when an organization opts in. An
  alert appears only when the owner enables "Generic patterns". A blocked push
  prints a per-secret bypass URL.

**Commit points:** git (no `.jj`). The user lands each commit through `nr` (a
generation commit). The session hands a commit to the `git-vcs` agent only when
the user asks for a separate one. No stage commits on its own. A separate
commit stages only this plan's files.

1. After Task 1: the ungoogled-chromium declaration with uBlock Origin and the
   browser-addons inputs. The doc stage writes its docs into the same commit:
   - The `feature-index.md` `ungoogled-chromium/` entry. It names the
     `nix-browser-addons` inputs and says that `nr` carries uBlock Origin
     updates.
   - An explanation page that takes over the Fixed facts and Decisions 1, 2,
     and 7, including the two third parties.
   No how-to is needed, because no update step is manual.
2. After Task 2: Open Claude in Chrome. Its docs go into the same commit:
   - `docs/reference/claude-code.md`: the new file, the MCP server, and the
     native host
   - `docs/explanation/claude-code-config.md`: the MCP passage
   - the `feature-index.md` `claude-code/` entry
   - a section on the commit-1 explanation page that takes over Decisions 3,
     4, 5, and 6: the placement gate, tracking main, the throwaway key, and
     the full setup
   The docs must not repeat a tool count. The Spec's 21 is stale, the server
   listed 26 at `6a37c29`, and upstream adds tools freely.
3. After the user's cedar confirmation in Task 3, the doc stage retires this
   spec in its own commit. The spec stays until the user confirms macOS CRX
   support, because that is this design's open risk.

**New dependencies:** three flake inputs, all approved in the Spec.
`nix-browser-addons` and `nix-browser-addons-data` come from Decision 2, and
`open-claude-in-chrome` from Decision 4. The build tool `go-crx3` comes from the
locked nixpkgs. The plan proposes no other dependency or pattern.

## Tasks

### Task 1: ungoogled-chromium as a program declaration, with uBlock Origin

**Files:**
- Modify (rewrite): `modules/programs/ungoogled-chromium/ungoogled-chromium.nix`
- Modify: `modules/host-config/roles/desktop/desktop.nix` (the
  `ungoogled-chromium` entry in `flake.modules.nixos.role-desktop` and in
  `flake.modules.darwin.role-desktop`)
- Modify: `modules/hosts/cedar/configuration.nix`,
  `modules/hosts/aspen/configuration.nix`,
  `modules/hosts/redwood/configuration.nix`,
  `modules/hosts/spruce/configuration.nix` (`globalPrograms`)
- Regenerate: `flake.nix` (`nix run .#write-flake`), `flake.lock`
  (`nix flake lock`)

**Interfaces:**
- Consumes: the `flake.programs` generator and the `flake.hosts`
  `globalPrograms` routing.
- Produces:
  - flake inputs `inputs.nix-browser-addons` and
    `inputs.nix-browser-addons-data`
  - the generated units `flake.modules.nixos.ungoogled-chromium`,
    `flake.modules.darwin.ungoogled-chromium`, and
    `flake.modules.homeManager.ungoogled-chromium-config`.
  Every home's `programs.chromium` is enabled with `package = null`. Task 2
  appends to it.

All commands run from `/private/etc/nix-darwin` with the sandbox disabled.

- [ ] **Step 1: Run the probes and confirm the "before" state**

```sh
nix eval --json '.#homeConfigurations."jake.neau@cedar".config.home.file' \
  --apply 'f: builtins.filter (n: builtins.match ".*Chromium.*" n != null) (builtins.attrNames f)'
nix eval --json '.#homeConfigurations."jakeneau@redwood".config.home.file' \
  --apply 'f: builtins.filter (n: builtins.match ".*chromium.*" n != null) (builtins.attrNames f)'
```

Expected: `[]` and `[]`, because no home writes Chromium files yet.

- [ ] **Step 2: Rewrite `modules/programs/ungoogled-chromium/ungoogled-chromium.nix`**

```nix
{ inputs, ... }:
{
  # Ungoogled Chromium: Chromium with Google integration and phone-home removed.
  #
  # Split: nixpkgs only builds Chromium on Linux, so NixOS installs the
  # nixpkgs package while macOS pulls the Homebrew cask (as the other browsers
  # do there). home-manager only writes the per-user extension files.

  # Pinned extension CRXs, republished daily; nr carries new releases.
  flake-file.inputs = {
    nix-browser-addons = {
      url = "github:andre4ik3/nix-browser-addons";
      inputs.nixpkgs.follows = "nixpkgs";
      # Track the daily data branch, not the copy frozen in its own lock.
      inputs.data.follows = "nix-browser-addons-data";
    };
    nix-browser-addons-data = {
      url = "github:andre4ik3/nix-browser-addons/data";
      flake = false;
    };
  };

  flake.programs.ungoogled-chromium = {
    install.linux = [ "system" ];
    install.macos = [ "cask" ];
    # false: home-manager's module is programs.chromium, so the default would
    # null a programs.ungoogled-chromium.package option that does not exist.
    hasEnableOption = false;

    config =
      { pkgs, ... }:
      let
        # Applied to this home's pkgs; legacyPackages would instantiate a second nixpkgs.
        ublock = (inputs.nix-browser-addons.overlays.default pkgs pkgs).chromiumExtensions.ublock-origin;
      in
      {
        programs.chromium = {
          enable = true;
          # Installed system-wide above; this only writes the config files.
          package = null;
          # ungoogled-chromium never downloads extensions, so each one is a
          # local CRX whose version must equal its manifest's.
          extensions = [
            {
              id = ublock.passthru.id;
              inherit (ublock) version;
              crxPath = ublock;
            }
          ];
        };
      };
  };
}
```

- [ ] **Step 3: Remove the two role imports in `desktop.nix`** (two targeted edits)

In `flake.modules.nixos.role-desktop`, replace

```nix
          network
          ungoogled-chromium
          blender
```

with

```nix
          network
          blender
```

In `flake.modules.darwin.role-desktop`, replace

```nix
      mac-app-util
      ungoogled-chromium
    ];
```

with

```nix
      mac-app-util
    ];
```

Then run `git diff -- modules/host-config/roles/desktop/desktop.nix`. Confirm
that the diff removes exactly the two `ungoogled-chromium` lines and nothing
else.

- [ ] **Step 4: Add the program to every host's `globalPrograms`**

Make one targeted edit per file:

- `modules/hosts/cedar/configuration.nix`: after `"windows-app"`, add
  `"ungoogled-chromium"`.
- `modules/hosts/aspen/configuration.nix`: after `"steam"`, add
  `"ungoogled-chromium"`.
- `modules/hosts/redwood/configuration.nix`: after `"openpencil"`, add
  `"ungoogled-chromium"`.
- `modules/hosts/spruce/configuration.nix`: after `"openpencil"`, add
  `"ungoogled-chromium"`.

The result for cedar, for example:

```nix
      "windows-app"
      "ungoogled-chromium"
    ];
```

- [ ] **Step 5: Regenerate `flake.nix` and lock only the new inputs**

```sh
nix run .#write-flake
git diff flake.nix
nix flake lock
git diff --stat flake.lock
jq -c '.nodes["nix-browser-addons"].inputs, .nodes.treefmt.inputs' flake.lock
```

Expected:
- `git diff flake.nix` adds only the `nix-browser-addons` input (its `url` and
  `inputs = { data.follows = "nix-browser-addons-data"; nixpkgs.follows = "nixpkgs"; };`)
  and the `nix-browser-addons-data` input (`flake = false`).
- `nix flake lock` reports added inputs `nix-browser-addons`,
  `nix-browser-addons/data` (follows), `nix-browser-addons/nixpkgs` (follows),
  `nix-browser-addons/treefmt`, `nix-browser-addons/treefmt/nixpkgs` (follows),
  and `nix-browser-addons-data`.
- `git diff --stat flake.lock` shows insertions only, with no deletions.
- `jq` prints
  `{"data":["nix-browser-addons-data"],"nixpkgs":["nixpkgs"],"treefmt":"treefmt"}`
  and `{"nixpkgs":["nix-browser-addons","nixpkgs"]}`.

If the lock shows any deletion, stop, run `git checkout -- flake.lock`, and
report it. Do not reach for `nix flake update`. Then stage the regenerated
files, so Task 2's diffs show only its own input:

```sh
git add flake.nix flake.lock
```

- [ ] **Step 6: Format**

```sh
nix fmt -- modules/programs/ungoogled-chromium/ungoogled-chromium.nix \
  modules/host-config/roles/desktop/desktop.nix \
  modules/hosts/{cedar,aspen,redwood,spruce}/configuration.nix
```

Expected: `0 changed`, because the code above is already formatted.

- [ ] **Step 7: Re-run the probes and confirm the "after" state**

```sh
nix eval --json '.#homeConfigurations."jake.neau@cedar".config.home.file' \
  --apply 'f: builtins.filter (n: builtins.match ".*Chromium.*" n != null) (builtins.attrNames f)'
```

Expected:
`["Library/Application Support/Chromium/External Extensions/blockjmkbacgjkknlgpkjjiijinjdanf.json"]`

```sh
nix eval --json '.#homeConfigurations."jakeneau@redwood".config.home.file' \
  --apply 'f: builtins.filter (n: builtins.match ".*chromium.*" n != null) (builtins.attrNames f)'
```

Expected:
`["/home/jakeneau/.config/chromium/External Extensions/blockjmkbacgjkknlgpkjjiijinjdanf.json"]`

```sh
nix eval --raw '.#homeConfigurations."jake.neau@cedar".config.home.file."Library/Application Support/Chromium/External Extensions/blockjmkbacgjkknlgpkjjiijinjdanf.json".text'
```

Expected:
`{"external_crx":"/nix/store/<hash>-ublock-origin-<version>.crx","external_version":"<version>"}`.
The two versions are equal (`1.75.0` on the 2026-10-07 data branch). If the
data branch has moved on since then, the version is newer and the ID filename
stays the same.

Next, confirm that each system installs the browser exactly once:

```sh
for h in cedar aspen; do nix eval --json ".#darwinConfigurations.$h.config.homebrew.casks" \
  --apply 'cs: builtins.length (builtins.filter (c: c.name == "ungoogled-chromium") cs)'; done
for h in redwood spruce; do nix eval --json ".#nixosConfigurations.$h.config.environment.systemPackages" \
  --apply 'ps: builtins.length (builtins.filter (p: (p.pname or "") == "ungoogled-chromium") ps)'; done
```

Expected: `1` four times. A `2` means a role still imports the aspect. A `0`
means a host lacks the `globalPrograms` entry.

- [ ] **Step 8: Build the macOS outputs**

```sh
nix build .#darwinConfigurations.cedar.system --no-link
nix build .#darwinConfigurations.aspen.system --no-link
nix build '.#homeConfigurations."jake.neau@cedar".activationPackage' --no-link
nix build '.#homeConfigurations."jakeneau@aspen".activationPackage' --no-link
```

Expected: all four succeed. The home builds fetch the uBlock Origin CRX
against the hash pinned in the data branch.

- [ ] **Step 9: Commit point 1.** Follow the Plan's commit points. Task 1's
  docs travel with it.

### Task 2: Open Claude in Chrome in the claude-code module

**Files:**
- Create: `modules/programs/claude-code/open-claude-in-chrome.pem`
- Create: `modules/programs/claude-code/open-claude-in-chrome.nix`
- Regenerate: `flake.nix` (`nix run .#write-flake`), `flake.lock`
  (`nix flake lock`)

**Interfaces:**
- Consumes: Task 1's enabled `programs.chromium` (`package = null`), and
  `claude-code.nix`'s `enableMcpIntegration = true` and `programs.mcp.enable = true`.
- Produces: flake input `inputs.open-claude-in-chrome` (non-flake). For homes
  with Claude Code it adds one `programs.chromium.extensions` entry
  `{ id; version; crxPath; }`, one `programs.chromium.nativeMessagingHosts`
  package holding
  `etc/chromium/native-messaging-hosts/com.anthropic.open_claude_in_chrome.json`,
  and `programs.mcp.servers.open-claude-in-chrome = { command; args; }`.

All commands run from `/private/etc/nix-darwin` with the sandbox disabled.
Both `nix` and BSD `sed -i` need that. BSD `sed -i` renames a temp file over
the original, and the sandbox blocks renames in this repo.

- [ ] **Step 1: Run the probe and confirm the "before" state**

```sh
nix eval --json '.#homeConfigurations."jake.neau@cedar".config.programs.mcp.servers' --apply builtins.attrNames
```

Expected: `["clickup","nixos"]`.

- [ ] **Step 2: Generate the throwaway signing key**

```sh
openssl genrsa 2048 | openssl pkcs8 -topk8 -nocrypt -out modules/programs/claude-code/open-claude-in-chrome.pem
head -1 modules/programs/claude-code/open-claude-in-chrome.pem
```

Expected: `-----BEGIN PRIVATE KEY-----`. Generate it exactly once. A new key
means a new extension ID.

- [ ] **Step 3: Create `modules/programs/claude-code/open-claude-in-chrome.nix`**

Write the file verbatim. `@OCIC_ID@` is a token that Step 4 replaces
mechanically.

```nix
{ inputs, ... }:
{
  # Open Claude in Chrome: a browser extension, its native messaging host, and
  # its MCP server, so Claude Code can drive ungoogled-chromium. Living in the
  # claude-code folder gates it: only homes with Claude Code evaluate or build
  # it, and it only adds programs.chromium entries, which home-manager writes
  # only where the ungoogled-chromium declaration enables programs.chromium.

  # Tracks upstream main; nr updates it with every other input.
  flake-file.inputs.open-claude-in-chrome = {
    url = "github:noemica-io/open-claude-in-chrome";
    flake = false;
  };

  flake.programs.claude-code.config =
    { pkgs, lib, ... }:
    let
      src = inputs.open-claude-in-chrome;

      # The extension ID derives from open-claude-in-chrome.pem, a throwaway
      # key that exists only to keep this ID stable.
      id = "@OCIC_ID@";
      hostName = "com.anthropic.open_claude_in_chrome";

      # Upstream never bumps its version and Chromium only installs a higher
      # one, so append the input's day number.
      upstreamVersion = (lib.importJSON "${src}/extension/manifest.json").version;
      version =
        assert lib.assertMsg (lib.length (lib.splitString "." upstreamVersion) <= 3)
          "open-claude-in-chrome: upstream version ${upstreamVersion} leaves no fourth part for the day count";
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
        # Only the default server: codemode and hybrid need wrangler and a Cloudflare Worker.
        postPatch = "rm -r codemode test";
      };
      hostRoot = "${host}/lib/node_modules/open-claude-in-chrome-host";

      # A store node, unlike install.sh's `command -v node`, survives garbage collection.
      nativeHost = pkgs.writeTextDir "etc/chromium/native-messaging-hosts/${hostName}.json" (
        builtins.toJSON {
          name = hostName;
          description = "Open Claude in Chrome Native Messaging Host";
          path = pkgs.writeShellScript "open-claude-in-chrome-native-host" ''
            exec ${lib.getExe pkgs.nodejs} ${hostRoot}/native-host.js "$@"
          '';
          type = "stdio";
          allowed_origins = [ "chrome-extension://${id}/" ];
        }
      );
    in
    {
      programs.chromium = {
        extensions = [
          {
            inherit id version;
            crxPath = crx;
          }
        ];
        nativeMessagingHosts = [ nativeHost ];
      };

      # Reaches Claude Code through claude-code.nix's enableMcpIntegration.
      programs.mcp.servers.open-claude-in-chrome = {
        command = lib.getExe pkgs.nodejs;
        args = [ "${hostRoot}/mcp-server.js" ];
      };
    };
}
```

- [ ] **Step 4: Compute the extension ID once and substitute it**

```sh
ID=$(openssl pkey -in modules/programs/claude-code/open-claude-in-chrome.pem -pubout -outform DER \
  | openssl dgst -sha256 -binary | xxd -p -c 64 | cut -c1-32 | tr 0-9a-f a-p)
echo "$ID"
sed -i '' "s/@OCIC_ID@/$ID/" modules/programs/claude-code/open-claude-in-chrome.nix
grep -c "@OCIC_ID@" modules/programs/claude-code/open-claude-in-chrome.nix
grep -c "id = \"$ID\";" modules/programs/claude-code/open-claude-in-chrome.nix
```

Expected: `echo` prints 32 letters from `a`-`p`. The first `grep -c` prints
`0`, and the second prints `1`. The later steps that need the ID read it back
from the file with
`sed -n 's/.*id = "\([a-p]\{32\}\)";.*/\1/p' modules/programs/claude-code/open-claude-in-chrome.nix`.

- [ ] **Step 5: Stage the new files**

```sh
git add modules/programs/claude-code/open-claude-in-chrome.nix modules/programs/claude-code/open-claude-in-chrome.pem
```

- [ ] **Step 6: Regenerate `flake.nix` and lock only the new input**

```sh
nix run .#write-flake
git diff flake.nix
nix flake lock
git diff flake.lock
```

Both diffs compare against the copies Task 1 staged. Expected: `git diff
flake.nix` adds only the `open-claude-in-chrome` input
(`url = "github:noemica-io/open-claude-in-chrome"`, `flake = false`).
`git diff flake.lock` adds only the `open-claude-in-chrome` node and its entry
under `nodes.root.inputs`. No other node's `rev` or `narHash` changes. If any
other node changed, stop and run `git checkout -- flake.lock`, which restores
Task 1's staged copy. Then report the problem. Do not reach for
`nix flake update`.

- [ ] **Step 7: Format and re-stage**

```sh
nix fmt -- modules/programs/claude-code/open-claude-in-chrome.nix
git add modules/programs/claude-code/open-claude-in-chrome.nix
```

Re-staging keeps the staged copy equal to the formatted file, which Step 10's
`git diff --exit-code` compares against.

- [ ] **Step 8: Re-run the probes and confirm the "after" state**

```sh
nix eval --json '.#homeConfigurations."jake.neau@cedar".config.programs.mcp.servers' --apply builtins.attrNames
```

Expected: `["clickup","nixos","open-claude-in-chrome"]`.

```sh
nix eval --json '.#homeConfigurations."jake.neau@cedar".config.programs.chromium.extensions' \
  --apply 'es: map (e: { inherit (e) id version; }) es'
jq '.nodes["open-claude-in-chrome"].locked.lastModified / 86400 | floor' flake.lock
```

Expected: the list holds two entries, in this order. The first is
`{"id":"blockjmkbacgjkknlgpkjjiijinjdanf","version":"<uBlock Origin version>"}`
(`1.75.0` on the 2026-10-07 data branch). The second is
`{"id":"<$ID>","version":"1.0.0.<N>"}`, where `<N>` is the number `jq` prints.

```sh
nix eval --json '.#homeConfigurations."jake.neau@cedar".config.home.file' \
  --apply 'f: builtins.filter (n: builtins.match ".*Chromium.*" n != null) (builtins.attrNames f)'
```

Expected: three keys. One is the uBlock Origin JSON, one is
`Library/Application Support/Chromium/External Extensions/<$ID>.json`, and one
is `Library/Application Support/Chromium/NativeMessagingHosts`.

- [ ] **Step 9: Build the cedar home, which runs the CRX's ID check**

```sh
nix build '.#homeConfigurations."jake.neau@cedar".activationPackage' --no-link
cat "$(nix eval --raw '.#homeConfigurations."jake.neau@cedar".config.home.file."Library/Application Support/Chromium/NativeMessagingHosts".source')/com.anthropic.open_claude_in_chrome.json" | jq .
```

Expected: the build succeeds. The manifest has `name`
`com.anthropic.open_claude_in_chrome`, `type` `stdio`, `allowed_origins`
`["chrome-extension://<$ID>/"]`, and a `path` that is a store script named
`open-claude-in-chrome-native-host`.

- [ ] **Step 10: Prove the ID check fails on a mismatch, then revert**

```sh
F=modules/programs/claude-code/open-claude-in-chrome.nix
ID=$(sed -n 's/.*id = "\([a-p]\{32\}\)";.*/\1/p' $F)
echo "$ID"
sed -i '' "s/id = \"$ID\";/id = \"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\";/" $F
nix build '.#homeConfigurations."jake.neau@cedar".activationPackage' --no-link 2>&1 | grep -c "is not aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
sed -i '' "s/id = \"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\";/id = \"$ID\";/" $F
git diff --exit-code $F
```

Expected: `echo` prints the 32-letter ID. If it prints nothing, stop, because
the test would then not bite. The build fails, `grep -c` prints `1` or more,
and `git diff
--exit-code` exits 0 (the file matches its staged copy again).

- [ ] **Step 11: Smoke-test the MCP server**

```sh
mkdir -p "$TMPDIR/ocic-home"
# Build first: --no-link outputs have no GC root.
nix build '.#homeConfigurations."jake.neau@cedar".activationPackage' --no-link
S='.#homeConfigurations."jake.neau@cedar".config.programs.mcp.servers.open-claude-in-chrome'
CMD=$(nix eval --raw "$S.command")
ARG=$(nix eval --raw "$S.args" --apply builtins.head)
(printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"probe","version":"0"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'; sleep 4) \
  | HOME="$TMPDIR/ocic-home" "$CMD" "$ARG" 2>/dev/null | jq -s '.[-1].result.tools | length'
```

Expected: a positive integer (26 at upstream `6a37c29`). That proves the store
`node` resolves every import with no `PATH`.

- [ ] **Step 12: Commit point 2.** Follow the Plan's commit points. Task 2's
  docs travel with it.

### Task 3: Full validation

All commands run from `/private/etc/nix-darwin` with the sandbox disabled.

- [ ] **Step 1: Flake check**

```sh
nix flake check
```

Expected: passes.

- [ ] **Step 2: Build the macOS systems and homes**

```sh
nix build .#darwinConfigurations.cedar.system --no-link
nix build .#darwinConfigurations.aspen.system --no-link
nix build '.#homeConfigurations."jake.neau@cedar".activationPackage' --no-link
nix build '.#homeConfigurations."jakeneau@aspen".activationPackage' --no-link
```

Expected: all succeed.

- [ ] **Step 3: Evaluate the NixOS systems and homes**

```sh
nix eval --raw .#nixosConfigurations.redwood.config.system.build.toplevel.drvPath
nix eval --raw .#nixosConfigurations.spruce.config.system.build.toplevel.drvPath
nix eval --raw '.#homeConfigurations."jakeneau@redwood".activationPackage.drvPath'
nix eval --raw '.#homeConfigurations."jakeneau@spruce".activationPackage.drvPath'
```

Expected: four `/nix/store/...drv` paths.

- [ ] **Step 4: Confirm the gate**

```sh
nix-store --query --requisites "$(nix eval --raw '.#homeConfigurations."jakeneau@aspen".activationPackage.drvPath')" | grep -c open-claude-in-chrome
nix-store --query --requisites "$(nix eval --raw '.#homeConfigurations."jake.neau@cedar".activationPackage.drvPath')" | grep -c open-claude-in-chrome
```

Expected: `0` for `jakeneau@aspen`, and a positive count for `jake.neau@cedar`.

- [ ] **Step 5: Hand the live check to the user** (never run `hr` yourself).
  Ask the user to run `hr` on cedar, fully quit and reopen ungoogled-chromium,
  and confirm the following:
  - Both extensions appear on `chrome://extensions`.
  - Each extension enables with one click.
  - `/mcp` in a new Claude Code session lists `open-claude-in-chrome`.
  - A browser tool call, such as a screenshot of a page, succeeds.

  If an extension does not appear, check `~/Library/Application
  Support/Chromium/External Extensions/` and the browser's
  `chrome://extensions` errors before anything else. That would be the macOS
  CRX risk from the Spec's Risks.

- [ ] **Step 6: Commit point 3.** After the user confirms, the doc stage
  retires this spec.
