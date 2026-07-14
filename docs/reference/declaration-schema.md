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

### install.linux

- Type: list of `"home"` and/or `"system"`. Default: `[]`.
- Install ways on Linux: `"home"` is a per-user home-manager install;
  `"system"` is NixOS system packages (`environment.systemPackages`).

### install.macos

- Type: list of `"home"` and/or `"cask"`. Default: `[]`.
- Install ways on macOS: `"home"` is a per-user home-manager install;
  `"cask"` is a homebrew cask — inherently machine-global.

A declaration with both lists empty throws at declaration eval.

### config

- Type: deferred module. Default: `{}`.
- The program's shared home-manager default config, in any module form:
  shorthand attrset, full module (`imports`/`options`/`config`), or module
  function. Carried plain — no priority markers; user-overridability comes
  from the boundary priority wrapper applied at host stamping (see
  [the framework's why](../explanation/declaration-framework.md)).

### hasEnableOption

- Type: bool. Default: `true`.
- Whether home-manager itself provides `programs.<name>.enable`. When
  `false`, the generated install unit declares that toggle itself and
  installs the `packages` list behind it, so opting out stays the uniform
  `programs.<name>.enable = false;`.

### packages

- Type: function of `pkgs` to a list of packages. Default:
  `pkgs: [pkgs.<name>]`.
- The packages the generated toggle installs. Only consulted when
  `hasEnableOption = false` — with a real home-manager module,
  home-manager installs the package itself. Covers programs whose package
  attribute differs from the declaration name or that install several
  packages (see `modules/programs/kubernetes/kubernetes.nix`).

### handWritten

- Type: list of `"nixos"`, `"darwin"`, `"homeManager"`. Default: `[]`.
- Classes whose aspect for this program is hand-written. The generator
  emits nothing for a listed class — no unit, no tombstone. Declaring an
  install way for a class listed here throws at declaration eval.

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
  platform, or declaration eval throws. Installs are opt-out-able per user
  via `programs.<name>.enable = false;`.

### installOverrides

- Type: attrset of strings, e.g. `{firefox = "cask";}`. Default: `{}`.
- Per-program install-way override: picks a declared non-default way for
  this host (per-user `"home"` wins by default). An override naming a way
  the program doesn't declare on the host's platform throws at declaration
  eval. Reroutes both halves of a `globalPrograms` entry; user-declaration
  resolution honors it too, filtering entries it routes to a system
  install. Semantics: [install-way
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
  or overridden to a system install, filters out silently. An entry with
  no per-user way on *any* platform throws at declaration eval.

### hosts.\<host\>.programs

- Type: list of strings. Default: `[]`.
- `flake.programs` names this user gets on this host only — the
  per-user-per-host channel the other two declarations can't express.
  Naming a host the user is not listed on (per `flake.hosts.<h>.users`)
  throws; an entry with no per-user way on that host's platform throws; an
  entry the host's override routes to a system install filters out
  silently. The filter-vs-throw table:
  [Add a per-user program](../how-to/declarations/add-a-per-user-program.md).
