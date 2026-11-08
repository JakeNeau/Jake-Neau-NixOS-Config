## Spec

### Purpose

Restructure `flake.programs.<name>` into per-platform blocks. Add a `"custom"`
install way so a program's own system module can install it. Platform-specific
home-manager config then needs no platform checks inside the module.

### Schema

A declaration has three blocks: `shared`, `linux`, and `macos`. Each block has
the same four fields:

- `install`: a list of install ways.
  - `linux.install`: `"home"`, `"system"`, `"custom"`.
  - `macos.install`: `"home"`, `"cask"`, `"custom"`.
  - `shared.install`: `"home"`, `"custom"`. These are the ways both platforms
    have.
- `config`: a deferred home-manager module. Default `{}`.
- `systemConfig`: a deferred module of the platform's system class. Default
  `null`.
  - `linux.systemConfig` is a NixOS module.
  - `macos.systemConfig` is a nix-darwin module.
  - The generator imports `shared.systemConfig` into both classes, so it may
    use only options that both NixOS and nix-darwin define.
- `packages`: a function of `pkgs` to a list of packages. The generator reads
  it only when `hasEnableOption = false`. The default is `pkgs: [ pkgs.<name> ]` when no
  block sets it.

Three fields stay at the top level because they describe the whole program:

- `hasEnableOption`: unchanged meaning. Default `true`.
- `handWritten`: unchanged meaning.
- `excludeFromVpn`: a bool, default `false`. `specs/vpn-exclusion.md`
  specifies its behavior. This spec only declares the option.

### Combining blocks

Each platform's effective declaration is its own block followed by `shared`.

- `install` and `packages` concatenate in that order: platform entries first,
  then shared entries.
- `config` and `systemConfig` import both modules.

### Install ways

- `"home"`: per-user home-manager install. Unchanged.
- `"system"` (Linux): `environment.systemPackages = [ pkgs.<name> ]` plus the
  effective `systemConfig`, if set.
- `"cask"` (macOS): `homebrew.casks = [ "<name>" ]` plus the effective
  `systemConfig`, if set.
- `"custom"` (both): routed like a machine-wide install. The generator installs
  nothing by default. The effective `systemConfig` installs the program.

Way resolution per (program, host) is unchanged. The host's
`installOverrides.<name>` wins first. Otherwise `"home"` wins when declared.
Otherwise the first declared way wins, in the combined order above. Every
non-`"home"` way, including `"custom"`, routes the system unit into the host
config and the `-config` unit into the baseline. User declarations filter
machine-wide ways exactly as they filter `"system"` and `"cask"` today.

### Generated units

Published unit names do not change: `homeManager.<name>`,
`homeManager.<name>-config`, `nixos.<name>`, `darwin.<name>`, and their
tombstones.

- `homeManager.<name>` imports `shared.config` unchanged. It imports
  `linux.config` and `macos.config` with their config gated on
  `pkgs.stdenv.hostPlatform.isLinux` or `isDarwin`. Option declarations in a
  platform block are not gated, because declaring an option on both platforms
  is harmless.
- `homeManager.<name>-config` gets the same composition. The
  `programs.<name>.package = null` rule applies when `hasEnableOption = true`
  and the program declares any machine-wide way: `"system"`, `"cask"`, or
  `"custom"`.
- The `packages` toggle installs the platform's effective `packages` on that
  platform only.
- `nixos.<name>` exists when the Linux effective `install` contains `"system"`
  or `"custom"`. Otherwise it is a tombstone.
- `darwin.<name>` exists when the macOS effective `install` contains `"cask"`
  or `"custom"`. Otherwise it is a tombstone.
- `handWritten` suppression is unchanged.

### Evaluation errors

Each error names the program and the fix:

- No install way on any platform.
- `"custom"` in a platform's effective `install` without an effective
  `systemConfig` for that platform.
- An effective `systemConfig` on a platform with no `"system"`, `"cask"`, or
  `"custom"` way.
- An `imports` entry inside `linux.config` or `macos.config`. Move the import
  to `shared.config`.
- Existing errors: a home way with `homeManager` hand-written, and a
  machine-wide way with that class hand-written.

### Migration

- Rewrite every `flake.programs` declaration to the new shape. No
  compatibility path keeps `install.linux` or `install.macos`.
- Move platform-checked config into platform blocks in `fastfetch`, `ghostty`,
  `yazi`, `pi`, `openpencil`, and `home-assistant`. Keep a platform check only
  where it guards a value inside a shared option, not a whole branch.
- Existing behavior must not change for any host or home.
- Hosts' `installOverrides`, `globalPrograms`, and user declarations keep their
  meaning.

### Documentation

Update `docs/reference/declaration-schema.md`,
`docs/reference/generated-units.md`,
`docs/how-to/declarations/add-a-program.md`,
`docs/how-to/declarations/add-a-per-user-program.md` where affected,
`docs/tutorials/first-program-declaration.md`,
`docs/explanation/install-way-resolution.md`,
`docs/explanation/declaration-framework.md`, `docs/reference/feature-index.md`,
and `.agents/skills/nix-config/SKILL.md`.

### Non-goals

- Per-platform published unit names.
- Changes to host or user declaration schemas, except accepting `"custom"` in
  `installOverrides`.

### Acceptance criteria

- `nix flake check` passes.
- The redwood and spruce systems build. The `jakeneau@redwood` and
  `jakeneau@spruce` homes build.
- The aspen and cedar systems evaluate. The `jakeneau@aspen` and
  `jake.neau@cedar` homes evaluate.
- Each host's `environment.systemPackages` or `homebrew.casks` names, and each
  home's `home.packages` names, match the pre-migration set, except for
  changes required by `specs/vpn-exclusion.md`.
- Each listed evaluation error fires with its message when triggered.

## Plan

## Tasks
