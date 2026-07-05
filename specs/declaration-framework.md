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
host-level reach-ins (`modules/hosts/cedar/configuration.nix:24` pushes
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
  users — on the macs both arrive through a `globalPrograms` listing, the only
  channel that can carry a cask. redwood and spruce list ghostty in their
  `globalPrograms` too: today Linux users get it only through the
  `homeManager.system-desktop` aggregate (`system-desktop.nix:161`), which
  stops importing it at the stage-5 cutover (see the one-channel consequence
  under *Host declarations*), so the host declaration is the sole channel on
  every platform. This replaces today's hand-written split in
  `modules/programs/ghostty/ghostty.nix`.
- **yazi** — per-user install on both platforms + config part; listed in the
  Linux hosts' `globalPrograms`, so every user gets the HM install by default
  and opts out with `programs.yazi.enable = false;` in their own folder.
  Generated: the full `homeManager` unit and the `-config` unit. The existing
  `homeManager.yazi` (`yazi.nix:36-81`, the Linux-gated termfilechooser
  wrapper — config only, no package install; imported at
  `system-default.nix:40`) folds into the declaration's `config` field, so the
  generated unit subsumes it under the same name. That import site keeps
  working **during stage 4 only** — the invariant that lets unconverted hosts
  keep receiving through the old line mid-migration; at the stage-5 cutover
  the aggregate import drops and the Linux hosts' `globalPrograms` listing is
  the sole channel. The `config` field also gains the per-user default-app claim
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
  Listed in `globalPrograms` on the hosts that want it — under the
  per-user-only rule that host channel is the only one that can carry the
  cask: aspen takes the default HM install; cedar overrides to the cask (the
  nix package breaks against the organization's SSO), so its users get
  `-config` through the baseline.
  Today firefox exists only as cedar's hand-written cask
  (`modules/hosts/cedar/configuration.nix:28-30`); the HM install path on
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
default, and the host's override map picks another declared way. For a
`globalPrograms` entry an override re-routes both halves by construction, per
the routing above — the system part into the host's generated system aspect,
the host's users onto the `-config` unit — so one line can never yield a cask
without config or a double install. For a program requested from a
`flake.users` declaration it does **not** re-route: user declarations are
per-user-only (see *User declarations*), so an override forcing the system
install **filters** the user's entry out instead — a user entry can never
cause a system install. The override lives on the *host*
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
`globalPrograms`) — buries the machine fact inside one channel's list, where
user-declaration resolution (which honors the same override to know when to
filter) can't see it.

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
The user aspect keeps only genuinely per-user config. The same rule retires
the system-type aggregates' imports of converted programs at the cutover:
`darwin.system-desktop` imports ghostty's cask aspect
(`system-desktop.nix:141`), `homeManager.system-desktop` imports its HM unit
(`system-desktop.nix:161`), and `homeManager.system-default` imports yazi
(`system-default.nix:40`). Once a converted program rides `globalPrograms`,
that is its **sole** channel — a surviving aggregate import would deliver a
second copy that the module system merges, and list-valued options concatenate
(ghostty's `keybind`/`font-feature` lists,
`modules/programs/ghostty/ghostty.nix:25,29`, would duplicate their entries).

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

- **Resolution** — user declarations are **per-user-only**: they only ever
  produce per-user (home-manager) units and never route anything into a host's
  system aspect — system installs belong to host declarations alone
  (`globalPrograms` + install-way overrides). Program names still resolve
  against `flake.programs` per (program, host), honoring the host's
  install-way override map, for both lists: resolved to the per-user HM way →
  the generated `homeManager.<name>` unit; resolved to a system install —
  either the platform has no per-user way at all (ghostty on macOS,
  cask-only) or the host's override forces one (firefox on cedar) → the entry
  **filters out** for that user on that host (the single-host list tightens
  the no-per-user-way case to a throw — see *Strictness*). Rationale (same
  program =
  covered): if the host actually installs it (e.g. via `globalPrograms`), the
  user rides that install and picks up the `-config` unit through the host
  baseline like every other user on the host — no user-channel action needed;
  if the host doesn't install it, the user simply doesn't have that program
  on that machine — a user declaration cannot force a machine-global install.
- **Strictness** — the two lists differ at declaration eval. `programs`
  (all-hosts) filters **silently** per host — a program with a per-user way
  on Linux but not macOS shows up on the user's Linux hosts and not their
  macOS hosts, and vice versa — with one coherence check: listing a program
  that declares no per-user way on *any* platform throws (it can never be a
  per-user program, so it doesn't belong on a user declaration), naming the
  user, the program, and the fix. `hosts.<h>.programs` (single-host) named
  that host deliberately, so a program with no per-user way for that host's
  platform **throws** rather than silently skipping — names the user, host,
  program, and fix. The override-covered case (an HM way exists for the
  platform, but the host's override forces the system install) still
  filters, not throws — the host provides the same program, so the request
  is satisfied, not contradicted.
- **Composition** — the generator folds `units(programs ∪ hosts.<h>.programs)`
  (after the resolution filtering above) into
  `homeConfigurations."<user>@<host>"` at stamping time: static
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

### User accounts & aspects

- `flake.factory.user` (`modules/factory/user/user.nix`) continues stamping the
  account aspects (nixos/darwin) and the `homeManager.<user>` wiring, minus all
  home-manager system-module wiring — the `home-manager.users.<u>.imports`
  blocks go away. The signature stays `username: isAdmin:`, no third
  parameter.
- There is **one kind of user**: every user's home config lives in this repo
  at `modules/users/<user>/`, tracked by git. (The earlier "external users
  keep a personal flake" category is deleted.)
- User folders are **ordinary parts of the config-group-owned tree**: a user
  who manages their home config in this repo is a `config` group member.
  Membership is per-host on darwin — each host aspect lists its own members
  (`modules/hosts/cedar/configuration.nix:21` lists jake.neau,
  `modules/hosts/aspen/configuration.nix:19` lists jakeneau) — while the
  NixOS list stays central
  (`modules/system/config-group/config-group.nix:30`); the darwin aspect
  keeps only the group mechanics (`users.knownGroups`, gid 600,
  `config-group.nix:37-39`). The existing one-time tree-wide ACL setup
  documented in `config-group.nix`'s comment block already covers the user
  folders — there is **no per-user ownership step**. Membership grants
  whole-tree write including `.git`, so users stage and commit their own new
  files; the one standing note is that flake eval ignores untracked files, so
  a brand-new file needs `git add` before `hr` sees it — which the user does
  themselves. Accepted trust model: membership grants write to the whole tree
  (any member can edit any folder and the system config), and it stays
  explicit per `config-group.nix`'s principle, so nothing is granted
  silently.
- The **factory never touches the `config` group**, which keeps meaning "who
  administers the system config" (whole-tree write); its member lists — the
  per-host darwin lines and the central NixOS list above — stay exactly as
  they are.
- Every factory-stamped user gets a `~/.config/nix-config` symlink to their
  own `modules/users/<user>/` folder, wired unconditionally in the factory's
  `homeManager.<user>` aspect via `config.lib.file.mkOutOfStoreSymlink` — a
  symlink into the live repo, not the store, so edits show up immediately
  without a rebuild. Fully declarative: it lands at home activation, with no
  imperative step.
- Per-user config/overrides live in `modules/users/<user>/` — the user's own
  folder, where plain assignment beats the `mkDefault` program defaults.

### Documentation

Stage 7 writes the documentation; this section is the enumeration it
executes, organized **by Diátaxis quadrant per [[skill:diataxis]]** — that
skill exactly, in its vocabulary and disciplines. The four types, one per
quadrant of the skill's two axes (acquisition/studying vs
application/working × action vs cognition): **Tutorial** —
learning-oriented (acquisition × action); **How-to guide** — task-oriented
(application × action); **Reference** — information-oriented (application ×
cognition); **Explanation** — understanding-oriented (acquisition ×
cognition). Its disciplines hold throughout: one page, one type; each
quadrant gets its own section/folder (`tutorials/`, `how-to/`, `reference/`,
`explanation/`) if a docs tree is adopted; never smuggle rationale into
reference or facts into explanation — split mixed pages instead. The
enumeration is checked in both directions:

- **Coverage** — every documentable part of the system (the existing tree
  plus everything the refactor introduces or invalidates) has a planned home
  in exactly one quadrant per page.
- **Quadrants** — all four quadrants have relevant documentation planned.
  Audit result: the first draft of this enumeration populated how-to,
  reference, and explanation but left **Tutorial empty** — nothing
  learning-oriented exists in the repo's docs or was planned; the
  *Tutorials* subsection below closes that gap.

The repo has **no `docs/` tree** today: documentation is `README.md`,
`SKILLS.md`, `CLAUDE.md`, and the four project skills under `.claude/skills/`
(nix-config, nvf, repo-permissions, default-apps), which double as the real
reference/explanation material. Whether stage 7 adopts the skill's quadrant
folder layout or keeps that shape — and, per topic, whether a skill
(agent-facing) or a doc (human-facing) is the right home — is a recorded open
question (see *Deferred*); the notes below name content and quadrant, not
location.

#### Tutorials (learning-oriented)

A tutorial is a lesson: the teacher decides what the learner does, and the
goal is confidence and skill, not a finished task — distinct from a how-to
even on the same territory (a learner who doesn't yet know what to ask vs a
doer with a goal, per [[skill:diataxis]]'s tutorial-vs-how-to confusion
note). Planned:

- **A new user's first home rebuild** — onboarding lesson for a fresh
  account on an existing host: gain config-group membership (log out/in or
  `newgrp config`), find your own `modules/users/<user>/` folder through the
  `~/.config/nix-config` symlink, make one small config change, `git add`
  it, run `hr`, and watch it land. Teaches the one-channel home model by
  doing. The adding-a-user runbook covers the same territory as a recipe for
  the admin; this page teaches the user being added.
- **Your first program declaration** — end-to-end lesson: pick a trivial
  program, write its `flake.programs` declaration, request it (a
  `globalPrograms` line or your own `flake.users` entry), dry-build, `hr`,
  and run it. Exercises the declare → generate → resolve → rebuild loop that
  the schema reference describes and the adding-a-program runbook
  compresses.
- **New-machine walkthrough** *(candidate — record, don't decide)* — the
  bootstrap how-to taken as a lesson, bare OS to first successful rebuild.
  Machines are added rarely and by the repo's owner, so the how-to may
  suffice; rides the deferred depth decision.

#### How-to guides (task-oriented)

Recipes for a goal a competent reader already has — just the steps, no
teaching.

- **Machine/repo bootstrap setup** — one guide collecting every one-time
  imperative step needed on a new machine or fresh clone. Known so far: the
  config-group ACL sequence (already written in `config-group.nix`'s comment
  block — the guide is where it graduates to; file ACLs aren't recorded by
  git, so the sequence must be re-run on a fresh clone) and the sops age key
  placement (`secrets/keys.txt` on Linux, key outside the repo on macOS —
  per the `config-group.nix` comments and `CLAUDE.md`). Stage 7 completes
  the enumeration by sweeping the repo for others.
- **Per-action runbooks** — one note per recurring action with an imperative
  component or a non-obvious declarative sequence. Known so far: **adding a
  user** (macOS account creation is imperative — nix-darwin never creates
  accounts, it only records the home dir, `modules/factory/user/user.nix:31-33`;
  the member line + rebuild is declarative, but the new member must log
  out/in or `newgrp config` before membership takes effect); **fresh clone /
  new checkout** (re-run the ACL sequence). The refactor adds three more:
  **adding a program declaration** (the fields, the class-suppression choice,
  the dry-build pass), **adding a host** (a `flake.hosts` declaration + the
  hand-written quirks aspect — replacing the retired new-host recipe at
  `.claude/skills/nix-config/SKILL.md:219-234`), and **adding a
  per-user-per-host program** (the `flake.users` `hosts.<h>.programs`
  one-liner and when it filters vs throws).
- **Rebuilding your home** — split from the standalone-home material per
  one-page-one-type: edit through `~/.config/nix-config`, `git add` any new
  file (flake eval ignores untracked files), run `hr` — or the full
  `home-manager switch -b backup --flake <repo>#<user>@<host>`. The *why*
  behind `-b backup` and the package-location change is explanation (below),
  not this page.
- **Existing-tree standouts** — recurring actions beyond the runbooks:
  adding a secret via sops, and the minecraft-server helpers (`mc-*` fish
  functions) if usage coverage grows to include them; rides the deferred
  depth decision.

#### Reference (information-oriented)

Dry, complete, accurate description of the machinery, mirroring its
structure — describes, never explains.

- **Declaration schema reference** — the `flake.programs` / `flake.hosts` /
  `flake.users` fields, writable once the deferred names land: install ways
  + `config` for programs; class, system, users, globalPrograms, the
  install-way override map, baseline imports for hosts; `programs` +
  `hosts.<h>.programs` for users.
- **Generated-units reference** — `homeManager.<name>`, `<name>-config`, the
  `nixos`/`darwin` system units, tombstones, class suppression; the per-user
  opt-out (`programs.<name>.enable = false;`) and its documented yazi edge
  (opting out also releases the file-type default but leaves the
  machine-global termfilechooser portal route to flip back per-user — see
  *Program declarations*).
- **Feature/aspect index** — one page mapping what exists and which hosts
  use it: 4 hosts, 2 users, the user factory, the 33 programs under
  `modules/programs/`, the system aspects (audio, caps-dual-role, cli,
  config-group, copy-paste-remaps, graphics with per-vendor self-activation,
  key-repeat, network, printing, system-constants), the system types
  (system-minimal/default/desktop, niri-desktop, local-ai), the nix tools
  (`modules/nix/tools/`), services (llama-server), and
  `modules/config/hidden-desktop-entries`. Today discoverability is
  grep-only. Not one page per module: the index maps what exists; whether
  any entry earns its own page is the deferred depth decision.

#### Explanation (understanding-oriented)

Discursive background — why it works this way, the alternatives and
trade-offs; read to understand, not to do. This quadrant is where this
transient spec's durable rationale graduates before the file is deleted.

- **The framework's why** — the three declarations, the one-channel home
  model, the mkDefault override seam, and the error strategy (throws at
  declaration eval, tombstones on import): the rationale this transient spec
  carries graduates here.
- **Install-way resolution** — per-(program, host) resolution: the
  HM-preferred default, the host override map rerouting both halves of a
  `globalPrograms` entry, user-entry filtering vs throwing, and the rejected
  shapes as the durable rationale.
- **Host-facts read-through** — how `systemConstants` reaches standalone
  homes via the evaluated system config, its trade-offs (slower `hr` eval; a
  non-evaluating system config blocks home rebuilds), and the retirement of
  the declare-and-forward push
  (`modules/system/system-constants/system-constants.nix:5-11`). The Constants
  pattern entry (`.claude/skills/nix-config/aspects.md:202-248`) stays valid
  for declaring and reading facts; its delivery story changes, and aspects.md
  likely gains a ninth "Declaration" entry (or equivalent) for the new
  pattern — exact shape is stage-7 judgment.
- **The standalone home model** — why exactly one channel delivers config to
  a home and the system module is gone; the consequences worth
  understanding: packages land in `~/.nix-profile` instead of
  `/etc/profiles/per-user/<user>`, the system module's
  `backupFileExtension` is lost (hence `-b backup` in every documented
  switch command), and `nr` now verifies all homes but reactivates only the
  invoking user's (via `hr`). The *doing* lives in the rebuilding-your-home
  guide above.
- **Existing-tree standouts** — subsystems whose design lives only in
  comments or nowhere: the declarative claude-code config
  (`modules/programs/claude-code/` — skills/agents/hooks/MCP/sandbox policy,
  a documentable subsystem of its own), the secrets flow (sops-nix + age —
  also the open README roadmap item), the stylix theming flow (especially
  post-restructure), system-constants and the graphics self-activation
  pattern, config-group's trust model, and the flake machinery
  (`modules/nix/flake-parts/`: factory, dendritic-tools,
  darwinConfigurations-fix). Which of these earn pages vs index entries is
  the deferred depth decision.

#### Staleness sweep (existing pages the refactor invalidates or that are already wrong)

The sweep's job is also Diátaxis triage: today's pages mix types, so each
item ends by naming the quadrant(s) its salvaged content lands in — split
into one page per type, never dual-homed.

- **`README.md`** — stale today and further invalidated by the refactor:
  `README.md:98` claims "intended to run on a NixOS system currently. Check
  back in the future for other environments like MacOS" — two darwin hosts
  (aspen, cedar) exist; installation (`README.md:109-121`) covers only the
  NixOS clone-into-`/etc/nixos` path — no macOS/nix-darwin install, no
  config-group ACL step (cross-reference the bootstrap guide); Usage
  (`README.md:130-138`) documents niri shortcuts and `nr`/`nrr` only — needs
  `hr` and the standalone home model, and omits the other autoloaded fish
  functions (`mc-*`, `np*`, `nc`, `suu` under
  `modules/programs/fish/functions/`; decide coverage, don't promise all);
  Roadmap still lists the dendritic move (`README.md:151`) and the nix-darwin
  environment (`README.md:154`) as open though both are done, while the SOPS
  instructions item (`README.md:156`) is genuinely open; contact/link sweep
  (`README.md:197`, shield URLs). Salvage: the About/design-principles
  material is explanation; the installation steps become the bootstrap
  how-to (and feed the new-machine tutorial candidate); Usage becomes
  how-to pointers (`hr`, `nr`, the fish functions); Roadmap and contact are
  project metadata outside the quadrants.
- **`SKILLS.md`** — "Syncing global skills across machines (nix)"
  (`SKILLS.md:21-40`) documents a `home.file.".claude/skills"` recursive-copy
  approach that predates the declarative claude-code module
  (`modules/programs/claude-code/claude-code.nix`); rewrite to point at the
  real mechanism or delete the section. The project-skills index
  (`SKILLS.md:42-66`) needs re-syncing with whatever skill changes stage 7
  makes. Salvage: the index is reference; the superseded sync section
  becomes a one-line reference pointer at the claude-code module, or is
  deleted.
- **`CLAUDE.md`** — the dry-build list gains the new outputs
  (`nix build .#homeConfigurations."<user>@<host>".activationPackage
  --no-link`); the `nr`/`nrr` caution and commit-format notes get re-checked
  against the changed `nr` and new `hr`. Salvage: agent-facing reference —
  keep it purely informational; rationale belongs in the explanation pages.
- **nix-config skill** — the largest item, upgraded from sweep-and-salvage to
  a **full rewrite**: the refactor retires the skill's primary organizing
  idea, not just details. The stale-spot catalog and the rewrite's decided
  scope — including the keep-the-name decision — are in *The nix-config skill
  rewrite* below.
- **repo-permissions skill** — says the darwin `config-group` aspect itself
  lists members (`repo-permissions/SKILL.md:17-18`); the uncommitted split
  moves membership per-host (`config-group.nix:38` comment;
  `modules/hosts/cedar/configuration.nix:21`,
  `modules/hosts/aspen/configuration.nix:19`) while NixOS stays central
  (`config-group.nix:30`). Two more spots assume a single darwin member:
  "the username differs by platform: `jakeneau` on NixOS, `jake.neau` on
  macOS" (`SKILL.md:21-22` — aspen's darwin member *is* jakeneau) and the
  macOS bootstrap step that appends only jake.neau (`SKILL.md:107`). Must
  absorb the split and cross-reference the bootstrap guide once the ACL
  comment block graduates out of `config-group.nix`. Salvage: the setup
  sequences graduate into the bootstrap how-to; the group facts (gid 600,
  the per-host member lists, the check commands) are reference.
- **machine-layout skill** (global claude-code config,
  `modules/programs/claude-code/config/skills/machine-layout/SKILL.md`) — its
  description headlines "one flake-parts/dendritic flake" (`SKILL.md:3`); that
  characterization gets the same declarations-first reframe, in a line. Its
  two prose pointers at the nix-config skill (`SKILL.md:3,67`) survive
  unchanged — the name is kept (below).

#### The nix-config skill rewrite

Post-refactor the repo's primary organizing idea is the three declarations —
`flake.programs` / `flake.hosts` / `flake.users` — plus generated wiring and
standalone home-manager. The skill's current framing (the dendritic pattern
as the way of working, hosts/users as hand-composed features, the
`mkNixos`/`mkDarwin` boilerplate, install-a-program-then-import-it) describes
the pre-refactor world; patching stale spots can't fix a wrong frame, so
stage 7 rewrites the skill wholesale around the new architecture. Decided
scope:

- **What dies (the stale-spot catalog).** The preamble's "the repo is
  mid-migration to this pattern" note (`SKILL.md:14-16`) — the migration this
  spec *completes*; "Turning aspects into real configurations"
  (`SKILL.md:137-164`) documents `mkNixos`/`mkDarwin`/`mkHomeManager` from
  `modules/nix/flake-parts/lib.nix` and the per-host `flake-parts.nix`
  boilerplate, both retired by the hosts generator; the "Installing a
  program" recipe (`SKILL.md:198-217` — define a per-class aspect, import it
  into a host or system-type aggregate) becomes the wrong default advice
  once `flake.programs` + `globalPrograms` is the primary channel and the
  one-channel rule retires aggregate delivery for converted programs; the
  new-host recipe (`SKILL.md:219-234`) shows the retired boilerplate; the
  new-user recipe (`SKILL.md:236-240`) leans on the Multi-Context pull
  ("pulling home-manager in from the system aspect") that dies with the
  system module; rule 4's `home-manager.sharedModules` double-import caution
  (`SKILL.md:178-179`) outlives the pushes it warns about; the validation
  section (`SKILL.md:253-260`) needs the homeConfigurations dry-build. In
  `aspects.md`: the **Multi-Context** entry (`aspects.md:69-98`) is built
  entirely on `home-manager.sharedModules` / `home-manager.users.<name>` —
  options that no longer exist in this repo's system evals post-cutover, so
  the pattern's mechanism is gone, not merely discouraged; the **Factory**
  entry's example (`aspects.md:309,314`) shows the exact
  `home-manager.users.${username}.imports` wiring stage 5 removes; the
  **Inheritance** caveat about sharedModules double-adds (`aspects.md:136`)
  shares rule 4's fate.
- **The reframe.** The dendritic *substrate* survives as underlying
  machinery — import-tree auto-import, `flake.modules.<class>.<name>`
  aspects, hand-written aspects staying first-class (principle 4); what dies
  is dendritic *composition* as the primary way of working. The rewritten
  skill leads with the three declarations and the generated wiring; aspects
  and auto-import are presented as the machinery beneath and the escape
  hatch for hand-written features (services/daemons, oddballs) — second,
  never the default recipe. The `description:` frontmatter (`SKILL.md:3`),
  which today names the dendritic pattern, is rewritten to name the
  declaration framework.
- **Name: kept — `nix-config` (decided).** The name describes the skill's
  *scope* — this Nix configuration — which the refactor doesn't change; it's
  the *description* that names the pattern, and the description is what goes
  stale. A pattern-named replacement (`declaration-framework` or similar)
  would bake the current architecture into the identifier — exactly the
  coupling that forced this rewrite — while buying nothing over rewriting
  the description, and would touch every reference site: the
  `.claude/skills/nix-config/` directory, the `name:` frontmatter
  (`SKILL.md:2`), the `[[skill:nix-config]]` links at
  `repo-permissions/SKILL.md:133,137`, `default-apps/SKILL.md:10,147,159`,
  and `nvf/SKILL.md:181,263`, the `CLAUDE.md:15` read-this-first pointer,
  the `SKILLS.md:46` index entry, the `README.md:77` pointer, the
  machine-layout skill's prose references
  (`modules/programs/claude-code/config/skills/machine-layout/SKILL.md:3,67`),
  and this spec's own `SKILL.md:`/`aspects.md:` citations. Keeping the name,
  every reference stays valid as-is. (Were a rename ever revisited, that
  list is its blast radius — an ordinary `git mv` of the in-repo, git-tracked
  skill directory plus those edits.)
- **Action coverage (required).** The rewritten skill is the complete
  agent-facing operational guide: for every kind of edit to the repository
  it says how to perform it. Enumerated: adding a program declaration (the
  fields, install ways, the class-suppression choice); adding a host (the
  `flake.hosts` declaration + the hand-written quirks aspect); adding a user
  (the `flake.users` declaration, the factory stamping, the user folder, the
  `flake.hosts.<h>.users` listing); making a declared program global on a
  host (the `globalPrograms` line); overriding a program's install way
  per-host (the host's override map); adding a per-user-per-host program (the
  `hosts.<h>.programs` one-liner and when it filters vs throws); writing or
  editing a hand-written aspect (the surviving rules and patterns);
  overriding a program default per-user (plain assignment in the user's
  folder beats `mkDefault`); opting out of a global program
  (`programs.<name>.enable = false;`); adding a flake input
  (`flake-file.inputs` + `nix run .#write-flake`); adding a secret
  (sops-nix); adding a service/daemon (hand-written aspects, beyond
  declarations); touching system types and baselines; validating (the
  dry-builds, including the new `homeConfigurations."<u>@<h>"` outputs).
- **Diátaxis seam.** The skill duplicates none of the stage-7 pages: where a
  how-to runbook or reference page covers an action, the skill states the
  action briefly and links to the page — it stays the agent-facing entry
  point into the docs, wherever they land. This settles the skill-vs-doc
  question *for this skill only*; the docs-location question stays deferred
  as recorded. Sequencing: the rewrite rides stage 7 and lands after the
  pages it links to. Salvage triage still applies to today's content — the
  layout/vocabulary/validation material is reference, the recipes are
  how-to, the pattern catalog (`aspects.md`) is explanation — with the skill
  keeping the brief agent-facing statement of each and the pages keeping
  the depth. New material stands: the three declarations, the generated
  units, the mkDefault override seam (or links to wherever that reference
  lands), plus aspects.md's ninth-"Declaration"-pattern question (see
  *Host-facts read-through*).

This spec records the enumeration; writing (and the location decision) is
stage-7 work.

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
  consequence: flake eval ignores untracked files, so a user's brand-new file
  must be staged before `hr` sees it — the user runs `git add` themselves
  (config-group membership grants `.git` write; see *User accounts &
  aspects*). Unverified detail to
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
- `throw` at declaration eval for a user's `programs` entry naming a program
  that declares no per-user way on *any* platform — it can never be a per-user
  program — names the user, the program, and the fix.
- `throw` at declaration eval for a user's `hosts.<h>.programs` entry naming a
  program with no per-user way for that host's platform — names the user, the
  host, the program, and the fix. (The override-covered case filters, not
  throws — see *User declarations*.)
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
  `minecraftServer`; name is the implementer's). The minecraft feature
  (`modules/nix/tools/nix-minecraft/nix-minecraft.nix`) today only imports
  the upstream module and adds its overlay — the enable lives in redwood's
  hand-written aspect (`modules/hosts/redwood/configuration.nix:150`). The
  enable **moves into the feature** (`services.minecraft-servers.enable = true`
  in `nix-minecraft.nix`) and the fact is set right beside it, making
  set-by-import real: importing nix-minecraft now means "this host runs a
  minecraft server". Redwood keeps the server definitions (the `servers`
  attrset, `eula`, `openFirewall` — everything except `enable`); redwood is
  the feature's only importer today, so nothing else changes meaning.
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
  (`modules/hosts/cedar/configuration.nix:24`) — become user-declaration
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
  (`modules/hosts/cedar/configuration.nix:28-30`) becomes the firefox program
  declaration plus, in cedar's host declaration, a `globalPrograms` entry and
  the override line — the entry requests the program, the override reroutes
  it to the cask — retired in the stage-5 cutover.
- Migration is **incremental** up to the cutover: the generators land first
  with nothing converted; programs convert one at a time, each validated by
  dry-builds; then all hosts, both users, and the old channel — including the
  system-type aggregates' imports of converted programs (see the one-channel
  consequence) — cut over in one atomic commit (stage 5), validated by
  dry-builds plus building the new homeConfigurations outputs.

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
- Where documentation lives: README + `.claude/skills/` today; whether stage 7
  adopts [[skill:diataxis]]'s quadrant folder layout (`tutorials/`, `how-to/`,
  `reference/`, `explanation/`) as a `docs/` tree — the skill's own
  give-each-quadrant-its-own-section discipline argues for it — and the
  per-topic skill-vs-doc placement (agent-facing vs human-facing), is the
  user's call at stage 7 — see *Documentation*. One placement is already
  settled: the nix-config skill stays a skill — the agent-facing entry point
  linking into the docs (see *The nix-config skill rewrite*).
- Documentation depth (which explanation and how-to standouts get pages vs
  index entries; whether the new-machine tutorial candidate is written) —
  stage-7 judgment with the user.

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
  (routing globalPrograms parts — including override-rerouted true-system
  parts — plus each listed user's factory-produced account aspect; user
  declarations contribute no system parts), and stamps
  `nixosConfigurations` / `darwinConfigurations` / `homeConfigurations."<user>@<host>"`,
  unioning each home's imports with the user-declaration units from users.nix.
  Subsumes the per-host `modules/hosts/<h>/flake-parts.nix` boilerplate and the
  `mkNixos`/`mkDarwin`/`mkHomeManager` helpers in
  `modules/nix/flake-parts/lib.nix` (rework or retire them as conversion
  proceeds; `mkHomeManager` is unused today).
- `modules/nix/flake-parts/declarations/users.nix` — declares the `flake.users`
  option (`programs` + `hosts.<h>.programs`; field names deferred) and the
  generator that resolves each entry against `flake.programs` into per-(user,
  host) sets of per-user HM units **only** — silently filtering entries from
  either list where the host's override forces the system install, and
  `programs` entries where the host's platform lacks a per-user way — plus
  the declaration-eval throws: a
  `hosts.<h>` entry naming a host the user isn't listed on in
  `flake.hosts.<h>.users`, a `programs` entry with no per-user way on any
  platform, and a `hosts.<h>.programs` entry with no per-user way for that
  host's platform.
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
  blocks (`user.nix:25,36`; at the stage-5 cutover — see stage 3). The
  signature stays `username: isAdmin:`, and the factory does no config-group
  work (the member lists — per-host on darwin in the host aspects, central
  for NixOS at `config-group.nix:30` — are untouched).
  Every stamped user gains the `~/.config/nix-config` symlink,
  unconditionally, in the `homeManager.${username}` aspect:

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
  drops in favor of its `globalPrograms` entry plus override; redwood and
  spruce list ghostty, replacing the aggregate delivery); the
  hand-written aspect keeps quirks,
  systemConstants values, config-group membership, daemon and system-type
  imports, but drops its
  user-account imports (e.g. `configuration.nix:10` on cedar — the generator
  places them); the `flake-parts.nix` boilerplate goes away.
- `modules/system/types/*` — system types expose their homeManager aggregates
  as baseline aspects the host baseline inherits; the
  `home-manager.sharedModules` pushes in `niri-desktop.nix:11`,
  `system-constants.nix:8`, `stylix.nix:16`, `mac-app-util.nix:23`,
  `fastfetch.nix:5` are all removed in favor of baseline/host-declaration
  routing, and the aggregates' imports of converted programs drop at the
  cutover — ghostty at `system-desktop.nix:141` (darwin cask) and `:161`
  (homeManager), yazi at `system-default.nix:40` — since `globalPrograms` is
  the sole post-cutover channel (see the one-channel consequence).
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
- `modules/nix/tools/nix-minecraft/nix-minecraft.nix` — gains
  `services.minecraft-servers.enable = true` (moved from redwood) with the
  new systemConstants fact set beside it.
- `modules/hosts/redwood/configuration.nix` — drops the `enable` line
  (`configuration.nix:150`); keeps the server definitions (`servers`, `eula`,
  `openFirewall`).
- `modules/users/jake.neau/` — gains the `flake.users."jake.neau"` declaration
  (kubernetes under `hosts.cedar.programs`, replacing cedar's reach-in; exact
  filename deferred); both user aspects drop their
  `homeManager.system-desktop` imports when their hosts cut over (baseline
  delivers it).
- `modules/programs/fish/functions/nr.fish` — verify-all-homes plus
  invoking-user reactivation as a call to `hr` (verify-loop details deferred).
- `.claude/skills/nix-config/SKILL.md` + `aspects.md` — full rewrite at
  stage 7 around the declaration framework, name kept; the scope — the
  declarations-first reframe, the per-action coverage list, links into the
  stage-7 pages, the rewritten `description:` frontmatter, and the
  aspects.md rework — is decided in *The nix-config skill rewrite*.

### Data flow

```
flake.programs.<p>  ──generator──▶  flake.modules.{homeManager,nixos,darwin} units
flake.users.<u>     ──generator──▶  per-(user,host) HM unit sets: units(programs ∪ hosts.<h>.programs),
                                      platform/override-filtered — never system parts
flake.hosts.<h>     ──generator──▶  host system aspect (system parts of globalPrograms
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
- Standalone home-manager installs a user's packages to `~/.nix-profile`
  instead of the system module's `useUserPackages` location
  `/etc/profiles/per-user/<user>`, so check PATH and plugin pickup during
  validation — fish's vendor-dir plugin pickup
  (`modules/programs/fish/fish.nix:95-97`) depends on where packages land.
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
   globalPrograms routing and user-declaration resolution (per-user HM units
   only, with the platform/override filtering), the systemConstants
   read-through injection, account-aspect placement, the common nixpkgs
   module, the users-consistency and no-per-user-way throws, and output
   stamping — again with nothing converted; prove shapes by `nix eval`
   against sample declarations, including that a `hosts.<h>` entry for a host
   the user isn't listed on throws, that a user entry resolving to a system
   install filters out (no HM unit and no system part for it anywhere), and
   that both no-per-user-way cases throw (`programs`: no per-user way on any
   platform; `hosts.<h>.programs`: none for that host's platform).
3. **User-factory changes — symlink only.** Add the
   unconditional `~/.config/nix-config` symlink to every stamped
   `homeManager.<user>` aspect (no flag, no config-group work — the factory
   signature stays `username: isAdmin:`). Do **not** touch the
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
   per-host-override case — its `globalPrograms` entry and override land in
   the stage-5 cutover; until
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
   remove the system-type aggregates' imports of converted programs — ghostty
   at `system-desktop.nix:141` (darwin cask) and `:161` (homeManager), yazi at
   `system-default.nix:40` — since globalPrograms (redwood and spruce list
   ghostty; the Linux hosts list yazi) is now the sole channel and a surviving
   aggregate line would double-deliver (ghostty's list-valued
   `keybind`/`font-feature` entries would duplicate — see the one-channel
   consequence),
   replace per-host reach-ins with user-declaration entries (cedar's
   kubernetes line becomes `hosts.cedar.programs = ["kubernetes"]` in
   jake.neau's `flake.users` declaration), swap cedar's firefox cask line for
   its `globalPrograms` entry plus install-way override, and drop both users'
   own
   `homeManager.system-desktop` imports. Old-channel side, same commit: the
   factory's `home-manager.users.<u>.imports` blocks, every `sharedModules`
   push (stylix, mac-app-util, system-constants, fastfetch, niri-desktop), the
   `home-manager` aspect imports in `system-default.nix:9,26`, and
   `modules/nix/tools/home-manager/home-manager.nix` itself all go; replace
   the `osConfig` reads in fish and fastfetch with systemConstants facts
   (incl. the new minecraft-server fact — moving
   `services.minecraft-servers.enable = true` from redwood's aspect into
   `nix-minecraft.nix` and setting the fact beside it), land the stylix HM
   restructure,
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
7. **Document and retire.** Settle the deferred docs-location and depth
   questions with the user, then execute the *Documentation* enumeration
   quadrant by quadrant per [[skill:diataxis]], drafting pages with the
   doc-writer agent and auditing coverage with doc-reviewer (the skill's
   related agents). **Tutorials**: a new user's first home rebuild; your
   first program declaration; the new-machine walkthrough if adopted.
   **How-to guides**: the machine/repo bootstrap guide (graduating the
   config-group ACL sequence out of `config-group.nix`'s comment block,
   adding the sops age key placement, and sweeping the repo to complete the
   enumeration of one-time imperative steps); the per-action runbooks
   (adding a user; fresh clone; adding a program declaration; adding a host;
   adding a per-user-per-host program); rebuilding your home; the sops and
   `mc-*` standouts per the depth decision. **Reference**: the
   declaration-schema and generated-units references; the feature/aspect
   index. **Explanation**: graduate the durable rationale — the framework's
   why, install-way resolution, the host-facts read-through, the standalone
   home model — plus the existing-tree standouts per the depth decision.
   Then **rewrite the nix-config skill** per *The nix-config skill rewrite* —
   name kept; declarations-first framing over the surviving dendritic
   machinery; the full per-action coverage list; the rewritten
   `description:` frontmatter; `aspects.md` reworked (Multi-Context retired,
   the ninth-pattern question) — describing each docs-covered action briefly
   and linking to its how-to/reference page, so the rewrite lands after
   those pages. Then run the staleness sweep — README, SKILLS.md, CLAUDE.md,
   the machine-layout description's one-line reframe, the repo-permissions
   skill — splitting each salvaged piece into its quadrant.
   Close by re-checking both completeness directions (every part covered;
   every quadrant populated). Then delete this spec.
