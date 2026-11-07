# Declaration schema reference

The fields of the three declarations — `flake.programs`, `flake.hosts`,
`flake.users` — as their generators declare them
(`modules/nix/flake-parts/declarations/{programs,hosts,users}.nix`). Recipes:
[Add a program](../how-to/declarations/add-a-program.md),
[Add a host](../how-to/declarations/add-a-host.md),
[Add a per-user program](../how-to/declarations/add-a-per-user-program.md). What each
declaration generates: [generated units](generated-units.md),
[generated host artifacts](generated-host-artifacts.md).

## flake.programs.\<name\>

One declaration per program, in that program's feature folder
(`modules/programs/<name>/`). Declared in
`modules/nix/flake-parts/declarations/programs.nix`.

A declaration has three blocks: `shared`, `linux`, and `macos`. Each block
has the same four fields, described below. Three more fields sit at the top
level because they describe the whole program: `hasEnableOption`,
`handWritten`, and `excludeFromVpn`.

```nix
flake.programs.ghostty = {
  linux.install = [ "home" ];
  macos.install = [ "cask" ];
  shared.config.programs.ghostty.enable = true;
  macos.config.home.file.".hushlogin".text = "";
};
```

Each platform's effective declaration is its own block followed by
`shared`. The `install` and `packages` lists concatenate in that order, so
platform entries come first. The generator imports the `config` and
`systemConfig` modules of both blocks.

### \<block\>.install

- Type: list of install ways. Default: `[]`.
- `linux.install` accepts `"home"`, `"system"`, and `"custom"`.
- `macos.install` accepts `"home"`, `"cask"`, and `"custom"`.
- `shared.install` accepts `"home"` and `"custom"`, the ways both platforms
  have.
- `"home"` is a per-user home-manager install.
- `"system"` adds the package to NixOS `environment.systemPackages`.
- `"cask"` adds a homebrew cask, which is machine-wide.
- `"custom"` is machine-wide too. The generator installs nothing for it,
  and the effective `systemConfig` installs the program.
- A declaration with no install way on any platform throws at declaration
  eval.

### \<block\>.config

- Type: deferred module. Default: `{}`.
- Home-manager config in any module form: a shorthand attrset, a full
  module (`imports`/`options`/`config`), or a module function. It carries
  no priority markers. The boundary priority wrapper at host stamping makes
  it user-overridable (see
  [the framework's why](../explanation/declaration-framework.md)).
- `shared.config` applies on both platforms.
- `linux.config` and `macos.config` apply their config only on their
  platform. Their option declarations apply on both platforms.
- A platform block's config may not contain `imports`, because an imported
  module would escape the platform gate. Move the import to
  `shared.config`. Otherwise the unit throws when a home imports it.

### \<block\>.systemConfig

- Type: null or deferred module. Default: `null`.
- An extra system module that the generated `nixos.<name>` or
  `darwin.<name>` unit imports. It carries machine-level config that no
  package provides, such as a daemon, a setuid wrapper, or an
  activation script (see `modules/programs/mullvad-vpn/mullvad-vpn.nix`).
- `linux.systemConfig` is a NixOS module. `macos.systemConfig` is a
  nix-darwin module.
- The generator imports `shared.systemConfig` on both platforms, so it may
  use only options that NixOS and nix-darwin both define.
- An effective `systemConfig` on a platform without a `"system"`, `"cask"`,
  or `"custom"` way throws at declaration eval.
- A `"custom"` way without an effective `systemConfig` throws at
  declaration eval.

### \<block\>.packages

- Type: null or function of `pkgs` to a list of packages. Default: `null`.
- The packages the generated toggle installs on each platform. The
  generator reads them only when `hasEnableOption = false`. With a real
  home-manager module, home-manager installs the package itself.
- When no block sets `packages`, the toggle installs `pkgs.<name>`.
- Use it for a package attribute that differs from the declaration name,
  for several packages (see `modules/programs/kubernetes/kubernetes.nix`),
  or for a different package on each platform (see
  `modules/programs/openpencil/openpencil.nix`).

### hasEnableOption

- Type: bool. Default: `true`.
- Whether home-manager itself provides `programs.<name>.enable`. When
  `false`, the generated install unit declares that toggle itself and
  installs the platform's `packages` behind it. A home install therefore
  opts out with `programs.<name>.enable = false;`. Without a `"home"` way,
  no unit declares the toggle. See [per-user
  opt-out](generated-units.md#per-user-opt-out).

### handWritten

- Type: list of `"nixos"`, `"darwin"`, `"homeManager"`. Default: `[]`.
- Classes whose aspect for this program is hand-written. The generator
  emits nothing for a listed class: no unit and no tombstone.
- Declaring an install way for a class listed here throws at declaration
  eval. `"home"` belongs to `homeManager`. The Linux machine-wide ways
  belong to `nixos`, and the macOS ones belong to `darwin`.

### excludeFromVpn

- Type: bool. Default: `false`.
- Whether the program's traffic bypasses every VPN installed on the host.
  Each VPN publishes how to exclude a program through `hostConstants.vpn`
  (see [host facts](../explanation/host-facts.md)).
- Linux: when `hostConstants.vpn.excludeCommands` is not empty, the
  `"system"`, `"custom"`, and `"home"` installs add a `lib.hiPrio` wrapped
  copy of the package. Each `bin/` executable runs every exclude line and
  then runs `exec` on the original. The copy wraps
  `config.programs.<name>.package` when that option exists in the installing
  module system. Otherwise it wraps the effective `packages` when
  `hasEnableOption = false`, and `pkgs.<name>` in the remaining case.
- macOS: when `hostConstants.vpn.syncExcludedApps` is not empty, system
  activation passes each excluded cask's app executable to every sync
  command. Home activation does the same for per-user installs.
- A program that resolves to `"custom"` on a macOS host with a sync command
  throws when the host evaluates. macOS exclusion supports `"cask"` and
  `"home"` installs only.
- Why and how: [VPN exclusion and Mullvad split
  tunneling](../explanation/mullvad-split-tunneling.md).

## flake.hosts.\<name\>

One declaration per host, in that host's folder (`modules/hosts/<name>/`).
Declared in `modules/nix/flake-parts/declarations/hosts.nix`.

### class

- Type: `"nixos"` or `"darwin"`. Required.
- OS class: picks `nixosSystem` vs `darwinSystem`, the account-aspect
  class, and the platform (`linux` / `macos`) install ways resolve against.

### system

- Type: string, e.g. `"aarch64-darwin"`. Required.
- The host's platform. Becomes `nixpkgs.hostPlatform` (as a `mkDefault`)
  and selects the nixpkgs package set for the host's stamped homes.

### users

- Type: list of strings. Default: `[]`.
- Users on this machine — the single authority: one entry yields the
  account (the factory aspect imported into the generated host-config
  aspect), the baseline delivery, and the
  `homeConfigurations."<user>@<host>"` output.

### globalPrograms

- Type: list of strings. Default: `[]`.
- `flake.programs` names every user on this machine gets by default. Each
  entry must have a declaration and at least one install way on the host's
  platform, or declaration eval throws. A user opts out of a home install
  with `programs.<name>.enable = false;`. A `"system"`, `"cask"`, or
  `"custom"` install is machine-wide, and a user can disable only its
  config. See [per-user
  opt-out](generated-units.md#per-user-opt-out).

### installOverrides

- Type: attrset of strings, e.g. `{firefox = "cask";}`. Default: `{}`.
- Per-program install-way override: picks a declared non-default way for
  this host (per-user `"home"` wins by default). An override naming a way
  the program doesn't declare on the host's platform throws at declaration
  eval. Reroutes both halves of a `globalPrograms` entry; user-declaration
  resolution honors it too, filtering entries it routes to a system
  install.
- An override may name any declared way, including `"custom"`. Every way
  except `"home"` is machine-wide. Semantics: [install-way
  resolution](../explanation/install-way-resolution.md).

### baselines

- Type: list of strings, e.g. `["role-desktop" "niri-desktop"]`.
  Default: `[]`.
- `flake.modules.homeManager` aggregate names (roles and extras like
  `niri-desktop` or `mac-app-util`) this host's generated baseline
  inherits.

## flake.users.\<name\>

One declaration per user, in that user's folder (`modules/users/<user>/`).
Declared in `modules/nix/flake-parts/declarations/users.nix`.

### programs

- Type: list of strings. Default: `[]`.
- `flake.programs` names this user gets on every machine they're on.
  Resolved per host: an entry with no per-user way on the host's platform,
  or overridden to a machine-wide install, filters out silently. An entry with
  no per-user way on *any* platform throws at declaration eval.

### hosts.\<host\>.programs

- Type: list of strings. Default: `[]`.
- `flake.programs` names this user gets on this host only — the
  per-user-per-host channel the other two declarations can't express.
  Naming a host the user is not listed on (per `flake.hosts.<h>.users`)
  throws; an entry with no per-user way on that host's platform throws; an
  entry the host's override routes to a machine-wide install filters out
  silently. The filter-vs-throw table:
  [Add a per-user program](../how-to/declarations/add-a-per-user-program.md).
