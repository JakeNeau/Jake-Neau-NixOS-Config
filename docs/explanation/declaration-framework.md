# The declaration framework's why

Why this repo is organized around three structured declarations —
`flake.programs`, `flake.hosts`, `flake.users` — instead of hand-composed
module imports. The dry description of what gets generated lives in the
reference pages ([schema](../reference/declaration-schema.md),
[units](../reference/generated-units.md),
[host artifacts](../reference/generated-host-artifacts.md)); this page is
the rationale.

## The problem the declarations solve

Before the framework, config reached a user's home through three ad-hoc
channels at once: user aspect imports, `home-manager.sharedModules` pushes
from system features, and host-level reach-ins that named specific users.
Home-manager ran as a system module, so a user couldn't apply their own
home without a system rebuild, and cross-platform programs hand-wrote
their install/config split per platform.

The framework replaces all of that with three declarations from which the
wiring is generated, under four principles:

1. **Home-manager installs everything it possibly can.** The system layer
   is reserved for what home-manager cannot do: daemons, casks,
   setuid/wrappers.
2. **Programs never name users.** A program's shared config is authored
   once, plain; the priority machinery below makes it user-overridable by
   ordinary assignment.
3. **All users are standalone home-manager managed.** Exactly one channel
   delivers config to a home — see [the standalone home
   model](standalone-homes.md).
4. **Uniformity.** Programs, hosts, and users are each one structured
   declaration; everything else is generated. Hand-written aspects stay
   first-class for what doesn't fit (services, daemons, oddballs like
   yazi's portal routing) — that's what the `handWritten` suppression
   field is for.

Each declaration covers one axis, and together they close the grid:
`globalPrograms` is per-host-all-users, the user's aspect is
per-user-all-hosts, and `flake.users.<u>.hosts.<h>.programs` is the
per-user-per-host channel neither of the others can express.

## The one-channel home model

A home is composed at stamping time from exactly one channel:
`homeConfigurations."<user>@<host>"` = the user's own aspect + the host's
baseline + the user's resolved declaration units. Nothing else may deliver
config to a home. The rule has teeth: `flake.modules` merges same-name
definitions and list-valued options concatenate, so a second delivery
channel (say, a role aggregate still importing a converted program)
silently duplicates list entries — ghostty's `keybind` list would gain
doubles. One channel makes double delivery structurally impossible rather
than merely discouraged.

## The boundary priority wrapper

The mechanism behind "programs never name users" is a priority ladder:

- **100** — the user's own config, plain assignment in
  `modules/users/<user>/`;
- **900** — everything shared, stamped by the wrapper at host stamping;
- **1000** — upstream modules' internal `lib.mkDefault`s.

User beats repo, repo beats upstream. 900 rather than `mkDefault`'s 1000
is deliberate: stamping shared config at 1000 would collide with upstream
internal defaults at equal priority, creating a new class of hard merge
conflicts, and would lose the repo-beats-upstream ordering.

When the hosts generator stamps a home, it walks everything except the
user's own aspect — baseline, role compounds, program units,
user-declaration units — and lowers every config leaf to
`lib.mkOverride 900`. The user's aspect is never wrapped: it *is* the
overriding layer.

### Why a graph walk and not one mkDefault

The obvious design — wrap each generated unit's config in a single
`lib.mkDefault` and let the module system push the priority down to the
leaves — is disproven, verified by eval against this flake's pinned
nixpkgs. Push-down delivers each leaf as override-outside/if-inside:
`mkOverride 1000 (mkIf c v)`. In nixpkgs's `lib/modules.nix`,
`dischargeProperties` runs before `filterOverrides` and pattern-matches
only `_type == "merge"` and `_type == "if"` — an override marker falls
through opaque, so the inner `mkIf` is never discharged and reaches the
type check as a raw `{_type = "if"; ...}` attrset ("A definition for
option ... is not of type ..."). The reverse nesting,
`mkIf c (mkDefault v)`, works fine.

This isn't theoretical: it bites ghostty (`package = mkIf isDarwin null`),
yazi (whose entire home config is one `mkIf isLinux`), and fish (a
top-level `mkMerge` of `mkIf` branches). So the wrapper recurses *into*
property markers and stamps the priority underneath them, producing the
working if-outside/override-inside nesting leaf by leaf.

The wrapper is a workaround for that upstream wart — `dischargeProperties`
not looking inside override markers. If nixpkgs ever teaches it to,
simplify the wrapper to one `mkDefault` per unit.

### How the walk behaves (as implemented)

The wrapper in `modules/nix/flake-parts/declarations/hosts.nix` has a
graph level and a value level.

Graph level — recurse the module graph down to its config values:

- a path is imported and recursed;
- a module function `f` becomes `args: wrap (f args)`, with
  `lib.mirrorFunctionArgs` preserving its argument names so the module
  system still injects `pkgs` and friends;
- a module whose whole body is a property marker (a top-level
  `mkMerge`/`mkIf`) is wrapped as one config value — this hardening isn't
  in the original design but real modules (fish) need it;
- full form (`config`/`options` present): the `config` part is
  value-wrapped, each `imports` entry recursed, all other keys kept;
- shorthand: every attribute is value-wrapped except `imports` (recursed)
  and module metadata (`_class`, `_file`, `key`, `disabledModules`,
  `require`).

Value level — descend the config value tree:

- `mkIf` → keep the `mkIf`, recurse into its content; `mkMerge` → recurse
  into its contents;
- an explicit `_type == "override"` (`mkForce`, a hand-written
  `mkDefault`/`mkOverride`) → left untouched: the author chose a priority;
- plain attrsets (except derivations) → recurse per-attribute;
- lists → left plain. Priority filtering keeps only the winning
  priority's definitions, so a 900 stamp wouldn't demote a shared list —
  it would delete it outright once any plain definition of the option
  exists (nvf's `home.packages` contribution vanishing against
  home-manager's own internal definitions was the proving case).
  Accumulative options must merge, not lose;
- everything else — scalars, derivations, other markers like
  `mkOrder` — → stamp `mkOverride 900`.

The implementation also skips several things the walk must *not* stamp,
all variations of one problem — options with opaque types
(`types.attrs`/`raw`/`unspecified`) never discharge markers stamped inside
their values, so a marker there leaks raw to readers:

- the top-level `lib` and `_module` config keys (plumbing like stylix's
  `config.lib.stylix` helpers and `_module.args`);
- store-path-like attrsets (`outPath`-bearing, non-derivation): flake
  inputs and fetched sources, typically plumbing data inside opaque
  options;
- functions: lib helpers, overlay and package functions — plumbing, not
  settings.

### Consequences

- Third-party modules delivered through baselines (stylix's home-manager
  module, mac-app-util, ...) are swept by the walk too: their plain
  internal settings become user-overridable at 900. Intended.
- A shared value that must survive user override needs an explicit
  `mkForce`.
- Shared lists merge with the user's own, upstream-style — both sit at
  plain priority thanks to the exemption. A user who wants to *replace* a
  shared list uses `mkForce`. The exemption obsoleted the old
  `lib.mkOverride 100` carve-out markers on generated `home.packages` and
  the [common nixpkgs module](../reference/common-nixpkgs.md)'s
  `nixpkgs.overlays`; only `nixpkgs.config` still carries one, for the
  opaque-type reason above, not for list merging.
- Accumulative *string* options (`types.lines`, extraConfig-style) still
  get stamped to 900 — at the value level they are indistinguishable from
  plain strings — so a shared definition is silently dropped if any
  plain-priority definition of the same option exists. Known residual
  hazard, tracked in `TODO.md`.

## The error strategy

Two failure modes, two mechanisms:

- **Incoherent declarations `throw` at declaration eval** — a program with
  no install way, an override naming an undeclared way, a user entry that
  can never be per-user, a `hosts.<h>` entry for a host the user isn't on.
  These are authoring errors; failing at eval, before any unit is imported
  anywhere, with a message naming the subject and the fix, catches them at
  the first `nix` command.
- **Plausible-but-unsupported imports get tombstones** — a generated
  module carrying a failing assertion. Importing `darwin.<p>` for a
  program with no cask is a *consumer* error at a distance; without the
  tombstone it would surface as "attribute ... missing" with no hint. The
  tombstone names the program and the fix. Suppressed classes
  (`handWritten`) get neither unit nor tombstone, because `flake.modules`
  merges same-name definitions and a tombstone would poison the
  hand-written aspect.

## Related pages

- [Install-way resolution](install-way-resolution.md) — how a
  (program, host) pair picks its way, and the shapes that were rejected.
- [The standalone home model](standalone-homes.md) — principle 3's
  consequences.
- [Host facts](host-facts.md) — how `hostConstants` reaches homes.
- [The flake machinery](flake-machinery.md) — the substrate the generators
  ride on.
