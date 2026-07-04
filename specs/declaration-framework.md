# Declaration-driven dendritic framework

> Status: **settled design, pre-implementation.** Every architectural fork below
> was decided interactively; only the items under *Deferred* remain open. This
> spec is transient per the specs lifecycle: once implemented, the durable
> rationale graduates into the Diátaxis docs and this file is deleted. It
> **supersedes** the old `specs/program-factory.md` (a program-install factory),
> which is deleted with this spec's creation.

## Spec

### What & why

Today config reaches a user's home through three ad-hoc channels: user aspect
imports (`modules/factory/user/user.nix:25,36`), `home-manager.sharedModules`
pushes (stylix, mac-app-util, system-constants, fastfetch, niri-desktop), and
host-level reach-ins (`modules/hosts/cedar/configuration.nix:21` pushes
kubernetes into jake.neau). Home-manager runs as a system module
(`modules/nix/tools/home-manager/home-manager.nix`, useGlobalPkgs /
useUserPackages), so a user cannot apply their own home without a system
rebuild, and programs like ghostty hand-write their cross-platform
install/config split (`modules/programs/ghostty/ghostty.nix`).

This change replaces all of that with three structured declarations — programs,
hosts, users — from which the wiring is generated, and moves every user to
standalone home-manager.

### Principles

1. **Home-manager installs everything it possibly can.** The system layer is
   reserved for what HM cannot do (daemons, casks, setuid/wrappers) plus a small
   root-survival kit of system packages (list deferred).
2. **Programs never name users.** Each program's shared default config is
   authored once and lands at `lib.mkDefault` priority (1000), so any user
   overrides it by plain assignment (priority 100) in their own space — normal
   module merge is the whole override mechanism.
3. **All users are standalone home-manager managed.** The home-manager system
   module is removed entirely. Exactly one channel delivers config to a home:
   the standalone output `homeConfigurations."<user>@<host>"` = the user's
   aspect + the host's baseline + the user's declared program units.
4. **Uniformity.** Programs, hosts, and users are each one structured
   declaration; everything else is generated wiring. Hand-written aspects remain
   first-class for what doesn't fit — services/daemons with rich system config,
   oddball programs. Declarations cover programs/hosts/users, not everything.

### Program declarations — `flake.programs.<name>`

One declaration per program, living in that program's feature folder
(`modules/programs/<name>/`). Fields:

- **Install ways** — the *set* of supported ways per platform (linux / macos):
  per-user HM install and/or a true-system method (e.g. a homebrew cask on
  macOS, which is inherently global). The generator emits units for every
  declared way. Where a platform supports more than one, per-user install is
  the preferred default — a host that says nothing gets the HM way; a host
  opts out per program via its install-way override map (see *Host
  declarations*). Most programs declare exactly one way per platform; ghostty
  stays the degenerate case (cask-only on macOS, where per-user install is
  impossible — semantics unchanged).
- **`config`** — the shared HM default config: a home-manager module — a full
  module *function* stays supported (fastfetch's `systemConstants` branch and
  ghostty's `mkIf` both work). The generated `-config` unit wraps the module's
  config output in **one** `lib.mkDefault` and relies on the module system's native
  property push-down to give every option leaf priority 1000 individually — no
  hand-rolled recursive wrapping (principle 2). Stated fact: a user overriding
  a list-valued option replaces the whole list (desired), and this never
  affects sibling options.

Each declaration generates importable units:

- `homeManager.<name>` — the per-user install (platform-gated with
  `pkgs.stdenv.isLinux`/`isDarwin` on content, never on imports) + imports the
  config unit.
- **Opt-out-able installs** — every generated install hangs off an overridable
  boolean: the program's HM `programs.<name>.enable` option set to
  `lib.mkDefault true` where one exists, a small generated toggle where one
  doesn't (exact shape deferred) — **never** a priority-marked `home.packages`
  list contribution, because priorities on list options discard lower-priority
  definitions wholesale (a user's plain `home.packages` assignment would
  silently uninstall every default program). Generated installs are defaults,
  not mandates: a user opts out with `programs.<name>.enable = false;` in
  their own folder.
- `homeManager.<name>-config` — config only, `mkDefault`'d, no package — for
  users on machines where the install is global/system-level.
- `nixos.<name>` / `darwin.<name>` — true-system install units (e.g. the cask),
  generated only for programs that declare one.
- **Tombstones** — any plausible-but-impossible unit (per-user install on a
  cask-only platform; any unit the declaration doesn't support) is generated as
  a module carrying a failing assertion that names the program and the fix, so
  importing it fails readably instead of "attribute ... missing".
- **Class suppression** — a declaration can mark a class as hand-written (field
  name deferred), and the generator emits *nothing* for that class — no unit,
  no tombstone. `flake.modules.<class>.<name>` merges all definitions of a
  name, so a generated tombstone would otherwise poison a substantive
  hand-written aspect of the same name (yazi's portal machinery below) or a
  not-yet-retired push aspect during migration. This serves principle 4:
  hand-written stays first-class.
- **`throw` at declaration time** for an incoherent declaration, naming the
  program and the fix.

Illustrative shapes (from the brainstorm; field names deferred):

- **ghostty** — per-user install impossible on macOS (cask, global-only) but
  possible on Linux; config part per-user everywhere. Generated: a `darwin`
  cask unit, a Linux-gated `homeManager` unit, the `-config` unit for mac
  users. This replaces today's hand-written split in
  `modules/programs/ghostty/ghostty.nix`.
- **yazi** — per-user install on both platforms + config part; listed in the
  Linux hosts' `globalPrograms`, so every user gets the HM install by default
  and opts out with `programs.yazi.enable = false;` in their own folder.
  Generated: the full `homeManager` unit and the `-config` unit. The existing
  `homeManager.yazi` (`yazi.nix:36-81`, the Linux-gated termfilechooser
  wrapper — config only, no package install; imported at
  `system-default.nix:39`) folds into the declaration's `config` field, so the
  generated unit subsumes it under the same name and its import site keeps
  working; the `config` field also gains the per-user default-app claim
  (`xdg.mimeApps.defaultApplications."inode/directory" = "yazi.desktop"`),
  conditioned on the enable switch so opting out also releases the file-type
  default. The hand-written `nixos.yazi` aspect
  (`modules/programs/yazi/yazi.nix:8-31`) slims to the portal routing
  (extraPortals + portal config) and its support packages — dropping **both**
  its `programs.yazi.enable = true` install line (`yazi.nix:9`, which would
  double-install against the per-user unit) and its system-wide
  `xdg.mime.defaultApplications` block (superseded by the per-user claim);
  that surviving aspect is beyond a declaration, so the nixos class stays
  suppressed. Documented edge: the machine-global FileChooser→termfilechooser
  portal route assumes the wrapper, so a user who opts out of yazi flips their
  portal route back with a one-line per-user override. The per-user *install*
  is new on macOS — today yazi's package is NixOS-system-level only, with no
  macOS presence.
- **firefox** — the per-host-varying case: HM install declared on both
  platforms *plus* a cask on macOS. Generated: the full `homeManager` unit,
  the `-config` unit (sets `programs.firefox.package = null` — home-manager's
  supported configure-without-installing mode), and a `darwin` cask unit.
  aspen takes the default HM install; cedar overrides to the cask (the nix
  package breaks against the organization's SSO), so its users get `-config`.
  Today firefox exists only as cedar's hand-written cask
  (`modules/hosts/cedar/configuration.nix:25-27`); the HM install path on
  other hosts is new capability, like yazi's macOS presence.

### Host declarations — `flake.hosts.<name>`

Fields (names deferred): **class** (nixos/darwin), **system** (e.g.
`aarch64-darwin`), **users** (list), **globalPrograms** (program names — one
line per program that every user on the machine gets by default; installs are
opt-out-able per the rule above), an **install-way
override map** (illustrative: `installOverrides.firefox = "cask"`; see the
resolution rule below), and **baseline imports**
(the system-type homeManager aggregates this host's baseline inherits — e.g.
`homeManager.system-desktop`, plus `homeManager.niri-desktop` on niri hosts).
Nothing else can tell the generator that redwood's baseline includes the niri
plumbing and cedar's doesn't; today that routing is the `sharedModules` push at
`modules/system/types/niri-desktop/niri-desktop.nix:11`, which dies with the
system module.

The framework routes each global program's parts by construction:

- True-system install parts → the host's generated system aspect.
- HM parts → a generated per-host **baseline** homeManager aspect applied to
  every listed user: the full HM unit for HM-installable programs, the
  `-config` unit for system-installed ones.

Which way applies is resolved per **(program, host)**, not per platform: when
the program declares several ways for the host's platform, per-user HM wins by
default, and the host's override map picks another declared way. An override
re-routes both
halves by construction, per the routing above — the system part into the
host's generated system aspect, the host's users onto the `-config` unit — so
one line can never yield a cask without config or a double install. It is
channel-agnostic: it applies whether the program came from `globalPrograms` or
a `flake.users` declaration's per-host list. The override lives on the *host*
because what it encodes is a fact about the machine (cedar's org SSO breaks
the nix firefox package) and a cask is inherently machine-global — a program-
or user-level knob would either violate principle 2 (programs never name
hosts/users) or misrepresent a global install as per-user.

**Rejected shapes** for way selection: branching the generated unit on a
`systemConstants` fact — the flake-level generator cannot read module-eval
constants at routing time, and the two coordinated moves (import the cask
unit, set the fact) drift silently into a double install; separate
`firefox`/`firefox-cask` declarations — splits one program's identity and
duplicates config; annotating list entries (`"firefox:cask"` in
`globalPrograms`) — breaks channel-agnostic resolution, forcing a user
declaration to know a host's install quirk.

The framework also stamps the flake outputs, replacing today's per-host
boilerplate
(`modules/hosts/<h>/flake-parts.nix` calling `flake.lib.mkNixos`/`mkDarwin`,
`modules/nix/flake-parts/lib.nix`):

- `nixosConfigurations.<name>` / `darwinConfigurations.<name>` for the host.
- `homeConfigurations."<user>@<host>"` for each listed user = user aspect +
  host baseline + the units from the user's declaration (see *User
  declarations* below). (The `flake.homeConfigurations` option comes from
  `inputs.home-manager.flakeModules.home-manager`, already imported in
  `modules/nix/tools/home-manager/flake-parts.nix`; `lib.mkHomeManager` exists
  but is unused today and gets reworked for this.)

The generator also imports each listed user's factory-produced account aspect
(`nixos.<u>` / `darwin.<u>`, per the declaration's class) into the host's
generated system aspect, retiring the hosts' hand-written account-import lines
(e.g. `modules/hosts/cedar/configuration.nix:10`). `flake.hosts.<h>.users` is
thus the single authority: one line yields the account, the home output, and
the baseline, by construction. Boundary: account *definition* stays in the
factory; only *placement* moves to the declaration.

The host's hand-written aspect (quirks, `systemConstants` values, daemon
imports, system-type import) composes alongside the generated wiring, as hosts
do today. Baselines inherit system-type baselines: system types like
`system-desktop` and `niri-desktop` carry homeManager baseline aspects too
(their existing `flake.modules.homeManager.<type>` aggregates), routed via the
baseline-imports field above.

One-channel consequence: user aspects **drop their own system-type HM imports**
(`modules/users/jake.neau/jake.neau.nix:12` and
`modules/users/jakeneau/homeManager.nix:7` both import
`homeManager.system-desktop`) — the baseline is the single source, so keeping
both would double-import the aggregate into
`homeConfigurations."<user>@<host>"`, violating the repo's one-import rule.
The user aspect keeps only genuinely per-user config.

**Host facts** (`systemConstants`,
`modules/system/system-constants/system-constants.nix`) reach homes by a
**lazy read-through of the evaluated system config** — neither `sharedModules`
nor `osConfig` exists on the standalone path. The hosts generator injects one
module into each host's generated baseline:
`systemConstants = inputs.self.<nixosConfigurations|darwinConfigurations>.<host>.config.systemConstants;`
(output attr chosen by the declaration's class), so homes see exactly the
facts the system eval resolved. Constants keep today's set-anywhere semantics:
values are assigned inside system module eval — host aspects, and bundles like
`modules/system/types/local-ai/local-ai.nix:8` (which stays byte-for-byte
unchanged); set-by-import remains a supported pattern, and import-set facts
flow through. The schema's single source stays
`flake.modules.generic.system-constants` (the HM side already gets the
declarations via `homeManager.system-default`). Trade-offs accepted: a home
eval now pulls (part of) the host's system eval — `hr` gets a few seconds
slower, eval-only — and a non-evaluating system config blocks home rebuilds
(mitigated: `nr` verifies everything). Boundary: the read-through delivers
*values* into modules; it cannot serve *routing* (install-way selection),
which the generator resolves at the flake level before any module eval — the
rejected shapes above stand.

### User declarations — `flake.users.<name>`

One declaration per user, living in that user's folder (`modules/users/<user>/`;
exact filename is the implementer's). It supplies the per-user program channels
the other two declarations can't: `globalPrograms` is per-host-all-users, the
user's aspect is per-user-all-hosts, and without this there is no
per-user-per-host channel ("jake.neau wants kubernetes, but only on cedar").
This completes the triad principle 4 already promises — programs, hosts, and
users are each one structured declaration. Fields (names deferred):

```nix
flake.users."jake.neau" = {
  programs = ["yazi"];                    # every machine this user is on
  hosts.cedar.programs = ["kubernetes"];  # only on cedar
};
```

- **Resolution** — program names resolve against `flake.programs` exactly as
  `globalPrograms` does — per (program, host), honoring the host's install-way
  override map: resolved to the HM way → the generated `homeManager.<name>`
  unit; resolved to a system install (e.g. a cask) → the
  true-system part routes into that host's generated system aspect **by
  construction, even when requested from a user declaration** (a cask is
  inherently global), and the requesting user gets the `-config` unit. Other
  users on the host simply don't import the config.
- **Composition** — the generator folds `units(programs ∪ hosts.<h>.programs)`
  into `homeConfigurations."<user>@<host>"` at stamping time: static
  composition per (user, host) pair, so no conditional imports are ever
  needed.
- **Division of labor** — program installs go through the user declaration
  (its `programs` / `hosts.<host>.programs` lists); the user aspect keeps only
  config values, overrides, and imports of hand-written non-declared aspects —
  never an import of a generated program unit, which would duplicate the
  declaration route.
- **`throw` at declaration eval** for a `hosts.<h>` entry naming a host the
  user is not listed on (per `flake.hosts.<h>.users`) — names the user, the
  host, and the fix.
- **Rejected shapes** — an auto-imported per-host aspect convention
  `flake.modules.homeManager."<user>@<host>"` (less uniform; a file per tweak
  instead of a one-liner), and `mkIf` on `systemConstants.hostName` inside the
  user aspect — still valid for plain per-host config *values*, but it cannot
  conditionally import a generated program unit.
- External users (personal flake taking this repo as input) get no
  `flake.users` declaration here; they compose per-host in their own flake
  from the exposed units.

### User accounts & aspects

- `flake.factory.user` (`modules/factory/user/user.nix`) continues stamping the
  account aspects (nixos/darwin) and the `homeManager.<user>` wiring, minus all
  home-manager system-module wiring — the `home-manager.users.<u>.imports`
  blocks go away.
- Users whose home config lives in this repo get the `config` group added by
  the factory (they need repo write; see `modules/system/config-group` and the
  repo-permissions skill).
- The same repo-resident flag also gives each such user a
  `~/.config/nix-config` symlink to their own `modules/users/<user>/` folder,
  wired in the factory's `homeManager.<user>` aspect via
  `config.lib.file.mkOutOfStoreSymlink` — a symlink into the live repo, not
  the store, so edits show up immediately without a rebuild. Repo write and
  the symlink are the two things a repo-resident user needs, so they travel
  together on one flag; external users are never repo-resident and correctly
  get neither.
- Per-user config/overrides live in `modules/users/<user>/` — the user's own
  folder, where plain assignment beats the `mkDefault` program defaults.
- External users (no repo access) keep a personal flake in their home folder
  that takes this repo as an input and imports its exposed homeManager
  aspects/baselines; their *account* is still declared here.

### Activation

- Every user applies their own home:
  `home-manager switch --flake <repo>#<user>@<host>`.
- A new autoloaded fish function **`hr`**
  (`modules/programs/fish/functions/hr.fish`, beside `nr.fish`) wraps that as
  the quick per-user reload: platform-select the flake path (`/etc/nixos` on
  Linux, `/etc/nix-darwin` on Darwin via `test (uname) = Darwin`), then
  `home-manager switch -b backup --flake "$flake#$USER@"(hostname -s)` —
  rebuilding and activating the **invoking** user's home and nothing else.
  Explicitly no git operations and no flake input updates. Accepted
  consequence: flake eval ignores untracked files, so a user adding a
  brand-new file must `git add` it themselves first. Unverified detail to
  check manually when `hr` lands: whether the home-manager CLI's
  `--flake path#jake.neau@cedar` fragment handles the dotted username.
- `hr` needs the `home-manager` CLI on every user's PATH; the common nixpkgs
  module for standalone homes (see *Plan*) sets
  `programs.home-manager.enable = true`, so every generated home ships it —
  the spec previously assumed the CLI existed without saying where it comes
  from.
- The `nr` rebuild function (`modules/programs/fish/functions/nr.fish`)
  changes: (a) its verify step covers **all** `homeConfigurations."<user>@<host>"`
  outputs in addition to all system configs, so a self-managed user's next
  switch can never hit a broken config — note the verification loop at
  `nr.fish:55-75` already enumerates `homeConfigurations` via
  `activationPackage.drvPath` eval, so this is confirming/strengthening
  coverage, not adding it; (b) after the system rebuild it reactivates the
  **invoking** user's home by simply calling `hr` — one implementation, not
  two — so Jake's flow stays one command. Other users' homes are never
  activated by `nr` — activation is theirs. Remaining implementation details
  (verify-loop strengthening) deferred.

### Errors

- `throw` at declaration eval for incoherent declarations — names the program
  and the fix; likewise for a user declaration's `hosts.<h>` entry naming a
  host the user isn't listed on (names the user, host, and fix).
- `throw` at declaration eval for a host install-way override naming a way the
  program doesn't declare on that host's platform — names the program, the
  host, and the fix.
- Tombstone assertions for plausible-but-unsupported imports.

### Migration consequences

- The home-manager system module (`modules/nix/tools/home-manager/home-manager.nix`)
  is **removed**; each homeConfiguration evaluates its own nixpkgs, so shared
  nixpkgs config must be provided explicitly via a common module — today
  `allowUnfree` comes from `modules/system/types/system-minimal/{nixos,darwin}-minimal.nix:6`
  and overlays from `modules/nix/tools/nur/nur.nix` and
  `modules/nix/tools/nix-minecraft/nix-minecraft.nix`. The common module must
  also carry the `permittedInsecurePackages` pins that HM-installed packages
  need (librewolf's, at `{nixos,darwin}-minimal.nix`; the system-level pins in
  `system-desktop.nix` stay where they are). Removing the system module also
  loses `backupFileExtension = "backup"` (`home-manager.nix:9`, important on
  the macs) — the documented switch command becomes
  `home-manager switch -b backup --flake <repo>#<user>@<host>`.
- The `flake.modules.{nixos,darwin}.home-manager` import sites go with it:
  `modules/system/types/system-default/system-default.nix:9` (nixos) and `:26`
  (darwin).
- `osConfig` is unavailable in HM modules; current users —
  `modules/programs/fastfetch/fastfetch.nix:25` and
  `modules/programs/fish/fish.nix:67` — must get facts from the host
  declaration instead. fastfetch's reads map onto existing `systemConstants`;
  fish's read of `osConfig.services.minecraft-servers.enable`
  (`fish.nix:82-88`) needs a **new systemConstants fact** (e.g.
  `minecraftServer`; name is the implementer's), set by the minecraft feature
  itself beside where it enables the service (the set-by-import pattern) —
  not by redwood's hand-written aspect.
- Every current `sharedModules` push migrates:
  - stylix (`modules/nix/tools/stylix/stylix.nix:16`) — has a standalone HM
    module, but the work is bigger than the one-line push: today per-user
    theming rides stylix's NixOS module auto-importing its HM module through
    the system HM module. Standalone homes need the stylix HM module imported
    into Linux baselines *and* the theme values (`stylix.nix:18-46`, currently
    NixOS-class only) shared across classes so the HM side states the same
    theme.
  - mac-app-util (`modules/nix/tools/mac-app-util/mac-app-util.nix:23`) — has
    an HM module; goes into the darwin hosts' baselines.
  - system-constants (`modules/system/system-constants/system-constants.nix:8`) — replaced by the generated baseline's read-through of the evaluated
    system config (see *Host facts*).
  - fastfetch (`modules/programs/fastfetch/fastfetch.nix:5`) and niri-desktop
    (`modules/system/types/niri-desktop/niri-desktop.nix:11`) — become
    globalPrograms / baseline entries.
- Host→user reach-ins — kubernetes on cedar
  (`modules/hosts/cedar/configuration.nix:21`) — become user-declaration
  entries, **not** user-aspect imports: an import in
  `modules/users/jake.neau/` would put kubernetes on all of jake.neau's
  machines, a regression. Instead kubernetes gains a small
  `flake.programs.kubernetes` declaration — per-user HM install of
  kubectl + k9s on both platforms, no config part; its hand-written
  `homeManager.kubernetes` aspect
  (`modules/programs/kubernetes/kubernetes.nix:2-7`) is exactly what the
  generated unit replaces, under the same name — and jake.neau's `flake.users`
  declaration lists it under `hosts.cedar.programs`.
- Cedar's hand-written `homebrew.casks = ["firefox"]`
  (`modules/hosts/cedar/configuration.nix:25-27`) becomes the firefox program
  declaration plus one override line in cedar's host declaration — retired in
  the stage-5 cutover.
- Migration is **incremental** up to the cutover: the generators land first
  with nothing converted; programs convert one at a time, each validated by
  dry-builds; then all hosts, both users, and the old channel cut over in one
  atomic commit (stage 5), validated by dry-builds plus building the new
  homeConfigurations outputs.

### Deferred — record only, do not decide

- Final names: `flake.programs` vs alternatives, the `<name>-config` suffix,
  baseline aspect naming, `flake.hosts` field names (including the install-way
  override map: `installOverrides` vs alternatives), `flake.users` vs
  alternatives, `hosts.<host>.programs` vs `programsByHost`, the user
  declaration's filename.
- The root-survival system package list.
- The generated install-toggle's exact shape for programs without an HM
  `programs.<name>.enable` option.
- Migration order (which program converts first; hosts cut over together).
- Remaining `nr` implementation details (verify-loop strengthening;
  reactivation is settled — it calls `hr`).

## Plan

### New files

- `modules/nix/flake-parts/declarations/programs.nix` — declares the
  `flake.programs` option (an `attrsOf` a small submodule schema) and the
  generator that maps each declaration into `flake.modules.homeManager.<name>`,
  `.<name>-config`, and `flake.modules.{nixos,darwin}.<name>` units — one for
  every declared install way — including tombstones and declaration-time
  throws. Mirrors how
  `modules/nix/flake-parts/factory.nix` attaches machinery at the flake-parts
  layer. (Exact file placement is the implementer's; option names deferred.)
- `modules/nix/flake-parts/declarations/hosts.nix` — declares `flake.hosts`,
  resolves each requested program's install way per (program, host) — the
  HM-preferred default plus the host's override map — and generates the
  per-host baseline homeManager aspect (including the systemConstants
  read-through module) and the host's generated system aspect
  (routing globalPrograms parts, plus the true-system parts of user-declared
  and overridden programs, plus each listed user's factory-produced account
  aspect), and stamps
  `nixosConfigurations` / `darwinConfigurations` / `homeConfigurations."<user>@<host>"`,
  unioning each home's imports with the user-declaration units from users.nix.
  Subsumes the per-host `modules/hosts/<h>/flake-parts.nix` boilerplate and the
  `mkNixos`/`mkDarwin`/`mkHomeManager` helpers in
  `modules/nix/flake-parts/lib.nix` (rework or retire them as conversion
  proceeds; `mkHomeManager` is unused today).
- `modules/nix/flake-parts/declarations/users.nix` — declares the `flake.users`
  option (`programs` + `hosts.<h>.programs`; field names deferred) and the
  generator that resolves each entry against `flake.programs` into per-(user,
  host) unit sets, plus the consistency throw for a `hosts.<h>` entry naming a
  host the user isn't listed on in `flake.hosts.<h>.users`.
- A common nixpkgs module for standalone homes (shared `allowUnfree`,
  overlays), imported by every generated homeConfiguration; it also sets
  `programs.home-manager.enable = true` so every home ships the
  `home-manager` CLI that `hr` needs.
- `modules/programs/fish/functions/hr.fish` — the quick per-user home reload:
  platform-select the flake path, then
  `home-manager switch -b backup --flake "$flake#$USER@"(hostname -s)`; no
  git, no input updates.

### Changed files

- `modules/factory/user/user.nix` — drop both `home-manager.users.<u>.imports`
  blocks; add `config` group membership for repo-resident users
  (`users.groups.config.members`, per `modules/system/config-group/config-group.nix`).
  The factory signature is `username: isAdmin:` today — repo-residency is not
  derivable from that, so it gains an explicit flag/parameter (keeping
  config-group membership explicit-only, which that module's comment requires;
  external users never get it silently). The same flag gates the
  `~/.config/nix-config` symlink, added to the `homeManager.${username}`
  aspect:

  ```nix
  home.file.".config/nix-config".source =
    config.lib.file.mkOutOfStoreSymlink
      "${if pkgs.stdenv.isDarwin then "/etc/nix-darwin" else "/etc/nixos"}/modules/users/${username}";
  ```
- `modules/nix/tools/home-manager/home-manager.nix` — removed (the
  `flake-parts.nix` beside it keeps the `home-manager` flake input and the
  flakeModule import that declares `flake.homeConfigurations`).
- Program declarations added per program under `modules/programs/<name>/`,
  replacing the hand-written install aspects they cover (ghostty, yazi,
  firefox, fastfetch, kubernetes, ...). Hand-written aspects stay for
  services/daemons and oddballs.
- Host files `modules/hosts/{aspen,cedar,redwood,spruce}/` — each gains a
  `flake.hosts.<name>` declaration (class, system, users, globalPrograms,
  install-way overrides where needed — cedar's hand-written firefox cask line
  drops in favor of its override); the hand-written aspect keeps quirks,
  systemConstants values, daemon and system-type imports, but drops its
  user-account imports (e.g. `configuration.nix:10` on cedar — the generator
  places them); the `flake-parts.nix` boilerplate goes away.
- `modules/system/types/*` — system types expose their homeManager aggregates
  as baseline aspects the host baseline inherits; the
  `home-manager.sharedModules` pushes in `niri-desktop.nix:11`,
  `system-constants.nix:8`, `stylix.nix:16`, `mac-app-util.nix:23`,
  `fastfetch.nix:5` are all removed in favor of baseline/host-declaration
  routing.
- `modules/nix/tools/stylix/stylix.nix` — restructured: theme values shared
  across classes; the stylix HM module + theme land in Linux hosts' baselines.
- `modules/system/types/system-default/system-default.nix` — lines 9 and 26
  drop the `home-manager` aspect imports when the system module is removed.
- `modules/programs/fish/fish.nix` and `modules/programs/fastfetch/fastfetch.nix`
  — replace `osConfig` reads with `systemConstants` facts delivered through the
  baseline (fish needs the new minecraft-server fact; see above).
- `modules/system/system-constants/system-constants.nix` — gains that fact's
  *declaration*; the minecraft feature sets the value beside enabling the
  service. The `declare-and-forward` sharedModules push is retired.
- `modules/users/jake.neau/` — gains the `flake.users."jake.neau"` declaration
  (kubernetes under `hosts.cedar.programs`, replacing cedar's reach-in; exact
  filename deferred); both user aspects drop their
  `homeManager.system-desktop` imports when their hosts cut over (baseline
  delivers it).
- `modules/programs/fish/functions/nr.fish` — verify-all-homes plus
  invoking-user reactivation as a call to `hr` (verify-loop details deferred).

### Data flow

```
flake.programs.<p>  ──generator──▶  flake.modules.{homeManager,nixos,darwin} units
flake.users.<u>     ──generator──▶  per-(user,host) unit sets: units(programs ∪ hosts.<h>.programs)
flake.hosts.<h>     ──generator──▶  host system aspect (system parts of globalPrograms + user-declared programs
                                      + listed users' account aspects)
                                    host baseline HM aspect (HM/-config parts + system-type baselines
                                      + systemConstants = self.<class>Configurations.<h>.config.systemConstants)
                                    nixosConfigurations/darwinConfigurations.<h>
                                    homeConfigurations."<u>@<h>" = homeManager.<u> + baseline(<h>) + units(flake.users.<u>) + common nixpkgs module
flake.factory.user  ──unchanged──▶  account aspects + homeManager.<u>   (HM system wiring removed)
```

No new flake inputs are expected: standalone homes use the existing
`home-manager` input (`inputs.home-manager.lib.homeManagerConfiguration`). Any
that do turn out to be needed go through `flake-file.inputs` +
`nix run .#write-flake` (never hand-edit `flake.nix`), flagged for approval.

### Validation approach

No unit-test harness exists for Nix module code here; verification is:

- `nix eval` assertions — generated units have the expected shapes; incoherent
  declarations throw with their message; tombstones fire on import.
- `nix flake check`.
- Dry-builds of all four hosts and all homeConfigurations:
  `nix build .#darwinConfigurations.<h>.system --no-link` for aspen/cedar;
  NixOS (redwood/spruce) via `toplevel.drvPath` eval on this Mac (no Linux
  builder — see the darwin-cannot-build-nixos memory);
  `nix build .#homeConfigurations."<u>@<h>".activationPackage --no-link` (or
  drvPath eval for Linux homes).
- Never switch/activate; never commit/push. Format Nix with `alejandra`.
- Stage new `.nix` files with `git add` before evaluating — flake eval ignores
  untracked files.

## Tasks

Each stage is a commit point and ends with the full validation pass above.
Stage 4 repeats per program — one conversion at a time, dry-built before the
next; stage 5 is a single atomic cutover commit.

1. **Program-declaration generator.** Land `flake.programs` + the generator
   (units, `-config` split, tombstones, declaration-time throws) with **nothing
   converted**. Prove with `nix eval`: a sample declaration yields the expected
   units; an incoherent one throws; a tombstone assertion fires when its unit is
   imported into a probe eval; and a plain user assignment beats a shared
   default — including a default nested inside a `mkIf`.
2. **Host- and user-declaration generators + baselines + outputs.** Land
   `flake.hosts` + `flake.users` together (output stamping unions the user
   units into each home, so they're one coherent piece): baseline generation,
   globalPrograms and user-declaration routing, the systemConstants
   read-through injection, account-aspect placement, the common nixpkgs
   module, the users-consistency throw, and output
   stamping — again with nothing converted; prove shapes by `nix eval`
   against sample declarations, including that a `hosts.<h>` entry for a host
   the user isn't listed on throws.
3. **User-factory changes — repo-resident wiring only.** Add the
   repo-resident flag/parameter, `config`-group membership, and the
   `~/.config/nix-config` symlink (one flag gates both). Do **not** touch the
   `home-manager.users.<u>.imports` wiring yet: `user.nix:25,36` is the *only*
   path delivering `homeManager.<user>` (and with it `home.username` and the
   `homeManager` system-default minimals) into the system HM module. Removing
   it before the cutover fails cedar's dry-build — its reach-in would still
   define a home, now missing `home.stateVersion` (the HM system module
   defaults username/homeDirectory from the OS account, but stateVersion
   arrives only through the system-desktop → system-default → system-minimal
   chain this wiring imports,
   `modules/system/types/system-minimal/homeManager-minimal.nix:15`) — and
   silently empties every other host's homes while their dry-builds still
   pass. The wiring removal happens in the stage-5 cutover.
4. **Convert programs.** One declaration at a time (order deferred — confirm
   the first candidate with the user), each replacing the hand-written aspects
   it covers. Two invariants keep every intermediate commit building:
   generated `homeManager.<name>` units land under the **same name** the old
   channel's consumers already import (user aspects, system-type aggregates,
   pushers), so unconverted hosts keep delivering; and any class whose
   hand-written aspect must survive — yazi's slimmed portal `nixos.yazi`,
   fastfetch's pusher `nixos`/`darwin.fastfetch` until the stage-5 cutover —
   is **suppressed** in the declaration so no generated unit or tombstone
   collides with it.
   Start-set from the brainstorm: ghostty (the asymmetric case), yazi (the
   HM-plus-suppressed-system case), and firefox (the multi-way /
   per-host-override case — its override lands in the stage-5 cutover; until
   then cedar's hand-written cask line keeps delivering, colliding with
   nothing since it defines no `darwin.firefox` aspect), then fastfetch and
   the other pushed programs. kubernetes (trivial: install-only, no config)
   converts here too — it must precede stage 5, which references it from
   jake.neau's user declaration.
5. **Cut over — one atomic commit.** Convert all four hosts and both users
   together with the old channel's removal; every piece is mutually dependent
   (dropping the users' `homeManager.system-desktop` imports strands the
   old-channel homes without `home.stateVersion` — see stage 3 — while the
   factory wiring stays live, so neither half can land alone; and the wiring
   cannot outlive the module that declares its `home-manager.*` options).
   Hosts-and-users side: declare `flake.hosts.<name>` for all four hosts
   (class, system, users, globalPrograms, baseline imports), retire the hosts'
   `flake-parts.nix` boilerplate and their hand-written account-import lines,
   drop the hosts' imports of push aspects that globalPrograms now supersedes
   (e.g. the `fastfetch` import in each host's `configuration.nix` — otherwise
   this commit's un-suppression turns those names into imported tombstones),
   replace per-host reach-ins with user-declaration entries (cedar's
   kubernetes line becomes `hosts.cedar.programs = ["kubernetes"]` in
   jake.neau's `flake.users` declaration), swap cedar's firefox cask line for
   its install-way override, and drop both users' own
   `homeManager.system-desktop` imports. Old-channel side, same commit: the
   factory's `home-manager.users.<u>.imports` blocks, every `sharedModules`
   push (stylix, mac-app-util, system-constants, fastfetch, niri-desktop), the
   `home-manager` aspect imports in `system-default.nix:9,26`, and
   `modules/nix/tools/home-manager/home-manager.nix` itself all go; replace
   the `osConfig` reads in fish and fastfetch with systemConstants facts
   (incl. the new minecraft-server fact), land the stylix HM restructure,
   un-suppress classes whose pushers just died (their tombstones may now
   exist), and retire the superseded `flake.lib` helpers. Big but coherent —
   validate by building all four system configs and every new
   `homeConfigurations."<u>@<h>"` output.
6. **Land `hr` and update `nr`.** Add
   `modules/programs/fish/functions/hr.fish`; in `nr`, verify-all-homes
   (confirm/strengthen the existing `homeConfigurations` loop at
   `nr.fish:55-75`) and wire post-rebuild reactivation of the invoking user's
   home through `hr`. Check here the unverified dotted-username detail (see
   *Activation*). Verify-loop details deferred; do not run `nr` or `hr` to
   test — validate by review plus `fish -n` syntax check of both functions.
7. **Document and retire.** Graduate the durable rationale (the three
   declarations, the one-channel home model, the mkDefault override seam, the
   error strategy) into the repo docs / nix-config skill material per
   [[skill:diataxis]], then delete this spec.
