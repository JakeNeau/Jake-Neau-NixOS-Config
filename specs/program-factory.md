# Program install factory (`flake.factory.program`)

> Status: **design, pre-implementation.** This is a working document to be refined
> over further prompts and eventually implemented (then deleted per the specs
> lifecycle). Sections are tagged so we know what's settled vs. open:
> **[SETTLED]** strong support · **[FEEDBACK]** needs a decision · **[PAIN]** known
> hazard to handle in implementation.

## Spec

### What & why

Today every program is hand-written as `flake.modules.<class>.<name>` aspects. Some
programs should be installable **per-user** (home-manager) *or* **globally**
(system-wide), on **Linux and/or macOS**, optionally carrying a **default
home-manager config** that applies to all users but can later be overridden
per-user. That cross-cutting shape is currently copied by hand (see
`modules/programs/ghostty/ghostty.nix`). We want a Factory — modelled on the
existing `flake.factory.user` (`modules/factory/user/user.nix`) — that stamps the
matched per-class aspects from one concise spec, with clear errors for impossible
combinations.

### The decision **[SETTLED]**

Build the full factory, but use it **judiciously / opt-in**:

- **Use the factory** when a program needs ≥2 scopes/platforms or a shared default config.
- **Use a plain Simple aspect** (3 lines) for trivial single-scope/single-platform installs.
- **Keep hand-written** the nuanced cross-platform cases that read better by hand
  (`ghostty`, `sioyek`) — the deliberate "don't use the factory" examples.

Rationale: an internal design pass and external research independently concluded the
factory overlaps heavily with what the module system already provides (scope-by-import,
`enable`-style toggles, `mkDefault` override, `sharedModules`), so it earns its place
only where the boilerplate actually repeats. This is "simple and elegant above all"
applied to architecture: build the seam, but don't route everything through it.

### Core model **[SETTLED]**

**Scope is chosen by which class a host/user imports — it cannot be a runtime
argument.** Verified against the flake-parts source and nixpkgs `lib/modules.nix`:
module imports are typed by `_class` and resolved *before* `config`, so you cannot
pass scope to `imports` or detect "am I in a user vs a system" at eval time.

**The "four install types" collapse to the three standard classes** (no custom
classes — nothing would consume a `userLinux` class; `home-manager.users.<u>.imports`
is one list shared by both OSes):

| Install type | Class | Platform discrimination |
|---|---|---|
| per-user (any OS) | `homeManager.<name>` | `lib.mkIf pkgs.stdenv.isLinux/isDarwin` inside |
| global-Linux | `nixos.<name>` | the class *is* the platform |
| global-macOS | `darwin.<name>` | the class *is* the platform |

### Growth / swap path **[SETTLED]**

- **Default-config override seam:** the default config's values are authored with
  `lib.mkDefault` (priority 1000). A later, higher-priority per-user module
  (priority 100) wins by normal module merge — no extra mechanism. This is the seam;
  we do **not** build the user-supplied-config feature now.
- **Future: user-owned configs.** Users eventually supply their own home-manager
  config "from their home folder" (a self-service path, likely standalone
  home-manager `homeConfigurations.<user>`). Out of scope here; the `mkDefault` seam
  is what lets it slot in later without touching the factory.

## Plan

### Files

- **New:** `modules/factory/program/program.nix` — defines
  `config.flake.factory.program` and `config.flake.factory.programPresets`,
  mirroring `modules/factory/user/user.nix`. (`flake.factory` is already
  `attrsOf unspecified`, `modules/nix/flake-parts/factory.nix`, so it just attaches.)
- No host/user files need changing to *land* the factory. Conversions are opt-in.

### Factory spec schema **[SETTLED, names FEEDBACK]**

`flake.factory.program "<name>" { … }`:

| field | type | default | meaning |
|---|---|---|---|
| `platforms` | list of `"linux"`/`"macos"` | both | which OSes it may install on |
| `scopes` | list of `"user"`/`"global"` | both | `user`⇒`homeManager.<name>`; `global`⇒`nixos`/`darwin.<name>` |
| `macInstall` | `"nix"`/`"cask"` | `"nix"` | macOS install method; `cask` is **global-only** |
| `caskName` | string | `name` | homebrew cask id (when `macInstall=="cask"`) |
| `package` | `pkgs: <drv>` | `pkgs: pkgs.${name}` | package for nix installs |
| `config` | HM module / `null` | `null` | the single default config (authored with `mkDefault`) |
| `managePackage` | bool | `true` | `false`⇒ the config's `programs.<name>.enable` owns install |

### Generated aspects (illustrative; final code is the implementer's)

```nix
# homeManager.<name> — per-user; config + nix package, platform-gated
homeManager.${name} = {pkgs, lib, ...}: lib.mkMerge (
  lib.optional (cfg != null) { imports = [ defaultConfigModule ]; }   # STATIC gate, not mkIf
  ++ lib.optional (managePackage && hasLinux) (lib.mkIf pkgs.stdenv.isLinux { home.packages = [ (pkgFn pkgs) ]; })
  ++ lib.optional (managePackage && hasMacos && macInstall == "nix") (lib.mkIf pkgs.stdenv.isDarwin { home.packages = [ (pkgFn pkgs) ]; })
  # macos + cask + user scope installs NOTHING here (cask is global) — see errors
);

# nixos.<name> — global-Linux: pkg for all users + default config to all users
nixos.${name} = {pkgs, lib, ...}: {
  environment.systemPackages = lib.optional managePackage (pkgFn pkgs);
  home-manager.sharedModules  = lib.optional (cfg != null) defaultConfigModule;
};

# darwin.<name> — global-macOS: cask|pkg + default config to all users
darwin.${name} = {pkgs, lib, ...}: lib.mkMerge [
  (if macInstall == "cask"
   then lib.optionalAttrs managePackage { homebrew.casks = [ caskName' ]; }
   else { environment.systemPackages = lib.optional managePackage (pkgFn pkgs); })
  (lib.optionalAttrs (cfg != null) { home-manager.sharedModules = [ defaultConfigModule ]; })
];
```

Default config attaches **exactly once per scope** (user → the `homeManager` import;
global → `sharedModules`); a single install picks one scope.

### Config toggle (recursion-safe) **[SETTLED, namespace FEEDBACK]**

```nix
defaultConfigModule = {config, lib, pkgs, ...} @ args: {
  options.<TOGGLE-NAMESPACE>.${name}.useDefaultConfig =
    lib.mkEnableOption "the default home-manager config for ${name}" // { default = true; };
  # gate CONFIG VALUES (recursion-safe), NEVER imports:
  config = lib.mkIf config.<TOGGLE-NAMESPACE>.${name}.useDefaultConfig
    (if builtins.isFunction cfg then cfg args else cfg);
};
```

Constraint: a factory `config` sets config values only (no nested `options`/`imports`);
anything richer should be hand-written.

### Errors **[SETTLED]**

- **`throw` at factory-call time** for an incoherent spec — e.g. `scopes=["user"]`
  only + `macInstall="cask"` + `macos` (a cask cannot be per-user). Names the program
  and the fix, the moment it's declared.
- **Tombstone `assertions`** for a plausible-but-unsupported *import* — emit
  `darwin.<name> = { assertions = [{ assertion = false; message = "…"; }]; }` when
  `macos` isn't a platform, so importing it fails readably instead of "attribute missing".

### Presets + escape hatch **[FEEDBACK on names/semantics]**

Thin wrappers in the same file: `sharedGlobal` (global, both OS, cask on mac),
`sharedUser` (per-user, both OS, nix), `globalOnly` (global, no per-user), `allTypes`
(every scope×platform). Escape hatch = call `flake.factory.program name spec` directly.

### Implementation pitfalls to honor **[PAIN — bake into impl]**

- Keep the factory a **pure function of its arguments** — never read evaluation
  `config` at the import boundary (infinite recursion; the `user` factory precedent).
- **Never gate `imports` with `mkIf`** (imports resolve before config). Gate static
  `cfg != null` with `lib.optional`/`optionalAttrs`; the runtime toggle gates only
  config *values*.
- `assertions` live inside `config`; in home-manager they surface per-user, prefixed.
- Attach a given `sharedModules` entry from exactly one place (double-import footgun).
- With `useGlobalPkgs = true` (set in `home-manager.nix`), factory HM aspects must
  **not** set `nixpkgs.config`/`nixpkgs.overlays` — route those to system level.
- Homebrew cask is darwin-only and uses `homebrew.casks` (a nix-darwin option, not a class).

## Tasks

1. Create `modules/factory/program/program.nix` with `flake.factory.program` (schema +
   the three class generators + `defaultConfigModule` + error `throw`/tombstones),
   mirroring `modules/factory/user/user.nix` style.
2. Add `flake.factory.programPresets` (the four named wrappers).
3. `nix flake check` — file evaluates; `flake.factory.program` is a function.
4. `nix eval` a sample spec → confirm expected `homeManager`/`nixos`/`darwin` aspects;
   confirm an incoherent spec (`user`+`cask`+`macos`) **throws** with its message.
5. End-to-end proof: convert one real program per code path (per-user + global), then
   dry-build a NixOS host (`redwood`) and a Darwin host (`cedar`) with `--no-link`.
   (Darwin can't build NixOS here — validate NixOS via `toplevel` eval if needed.)
6. Document the usage convention (when to use the factory vs a Simple aspect) and
   graduate the durable rationale into the Diátaxis docs; then delete this spec.

## Open questions — need feedback **[FEEDBACK]**

1. **Toggle namespace.** Where does the "want the default config?" option live?
   Declaring `programs.<name>.useDefaultConfig` piggybacks on home-manager's real
   `programs.<name>` namespace (works, but couples to it and reads oddly for programs
   with no upstream HM module). Alternatives: a dedicated `factory.programs.<name>.*`
   or `myPrograms.<name>.config` namespace. **Which namespace?**
2. **Per-platform scope asymmetry (the ghostty shape).** A program whose *config* is
   per-user on both OSes but whose *install* is per-user-nix on Linux and global-cask
   on macOS does **not** fit a single repo-wide `scopes` value. `scopes=["user","global"]`
   + `macInstall="cask"` works but *also* emits a global-Linux `nixos.<name>` install
   that may be unwanted. Options: (a) treat these as hand-written cases (current
   judicious stance — `ghostty` stays by hand); (b) make `scopes` **per-platform**
   (`scopes = { linux = ["user"]; macos = ["global"]; }`). (b) is more general but more
   complex. **Accept (a), or invest in (b)?**
3. **Preset set & names.** Are `sharedGlobal` / `sharedUser` / `globalOnly` / `allTypes`
   the right four, with the right defaults (e.g. should `sharedGlobal` default
   `macInstall="cask"`)? Add/rename/drop any?
4. **Error strategy granularity.** Is `throw` (incoherent spec) + tombstone assertions
   (unsupported import) the right split, or should *all* unsupported combinations be
   tombstones for uniformity? How loud should a per-user-macOS-cask request be?
5. **First real conversions.** Which existing program(s) become the end-to-end proof
   (Task 5)? Under "judicious," converting a trivial app would violate the policy — we
   need one that genuinely benefits (≥2 scopes or shared config). Is there a current
   occupant, or do we accept the proof is a representative conversion we may revert?
6. **Naming.** `flake.factory.program` vs `flake.factory.app` vs `flake.factory.feature`?
   And does the per-program feature file still live under `modules/programs/<name>/`?

## Pain points / risks **[PAIN]**

- **Overlaps the module system.** For trivial programs the factory is *more* code than
  a Simple aspect. Mitigation: the judicious/opt-in policy — but it must be documented
  and actually followed, or the repo drifts toward ceremony.
- **No public prior art.** No well-known config ships a scope-selectable feature
  factory; the nearest cross-class factory is this repo's own `user` factory. We're
  assembling from documented patterns (Factory + Multi-Context + Conditional), not
  borrowing a proven whole — so edge cases are ours to find.
- **Per-user macOS cask is impossible** (homebrew is global). The schema must reject it
  loudly; the asymmetry in Q2 is the real-world version of this.
- **Double-install footgun.** Importing `homeManager.foo` into a user *and*
  `nixos`/`darwin.foo` into that user's host installs twice; the factory can't detect
  cross-file misuse — documentation-only mitigation.
- **`useGlobalPkgs` constraint** (don't set `nixpkgs.*` in HM aspects) and the
  **recursion / `mkIf`-on-imports** traps are easy to get wrong; they're called out in
  the pitfalls list and must be covered by the `nix eval` checks.
- **Verification has no unit-test harness.** Nix module code here is validated by
  `nix eval` / `nix flake check` assertions + dry-builds, not a test suite — so the
  RED-GREEN TDD step of the normal flow is replaced by eval-based assertions.

## Process notes

- Produced from the brainstorming in-conversation; per the repo flow this spec is
  consumed by the **code-writer** agent and **deleted** once implemented and the
  rationale has graduated into the Diátaxis docs.
- The earlier "extract the 22 inline desktop apps into their own folders" task is
  **deferred**; most are Linux-only single-scope and would be Simple aspects regardless,
  so this factory does not force their migration.
