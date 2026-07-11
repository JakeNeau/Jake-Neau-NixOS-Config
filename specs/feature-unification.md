# Feature unification

Part of an in-progress architecture-improvement design round. This file captures
the first settled change area; further change areas will be appended to `specs/`
as the round settles them.

## Spec

### The decision: programs and roles become one concept — features

There is no mechanical difference between a program and a role: a role is simply
a feature that imports other features. So the two merge into one declaration,
`flake.features.<name>`, replacing `flake.programs` (the schema in
`modules/nix/flake-parts/declarations/programs.nix` is renamed and extended, not
rebuilt). The repo vocabulary shifts with it: **"feature" now means the declared
unit itself**. The old sense of the word — any auto-imported file under
`modules/` — gets re-worded in the docs wherever the two clash.

### Schema additions

Two things are added to the declaration schema:

- **`imports`** — a list naming member features. A feature with members is a
  role; a feature without them is a leaf.
- **A global (system-level) config channel** alongside the existing per-user
  (home-manager) config channel.

Both config channels are typed `nullOr deferredModule`, default `null`. A
`deferredModule` can be a function, so it cannot be inspected for emptiness —
presence must be representable in the schema itself, and `!= null` is the
presence test.

### Expand-at-routing semantics (host side)

When a host lists a feature in its global list, the feature **flattens** —
recursively through `imports`, deduplicated as a set — into its member features,
and each member routes individually by its **own** resolved install way, exactly
as if it had been listed directly: casks to darwin, system packages to nixos,
home halves to the host baseline — honoring the host's `installOverrides` per
member.

- The role-feature's own global config applies once at system level; its
  per-user config lands in the baseline like a `-config` unit.
- Dedup-as-set means a member reached twice (via two roles, or a role plus a
  direct listing) is routed once — no double delivery.
- Roles may import roles; the recursion flattens.
- A pure aggregation feature has no install way of its own; only leaf features
  carry install ways.

### User-side import

A user listing a feature in their `flake.users` declaration resolves each
flattened member through the existing per-user rules.

A feature may have both faces: a **per-user face** (per-user config, a "home"
install way, members' per-user faces) and a **global face** (global config,
system/cask install). Per-user import delivers the per-user face; the global
face is **inert** on that channel — it activates only when a host applies the
feature. That split is expected, not an error.

The only **hard eval error** is a user importing a feature with *no* per-user
face at all (global-only): the import would deliver nothing. The check is one
predicate — roughly *has per-user config ∨ has a "home" way on this platform ∨
has members, recursively* — applied during the flatten traversal itself, erroring
on the first failure with a message naming the offending feature and the import
path that reached it.

By convention the roles we define stay one-or-the-other (global-applied vs
user-applied), but the mechanism allows both faces.

### Cross-feature integrations (`integrations` schema channel)

Today integrations are hard-coded unconditionally (e.g. ghostty's
`enableFishIntegration = true`), which only works by accident of home-manager
consuming those hooks solely when the target is enabled. The declaration schema
makes them explicit and conditional:

**Shape — `integrations.<name> = <module>`, recursively.** Each key names
another *declared* feature; the value is a config-only module applied when this
feature **and** the named feature are both enabled in the same home. The
mechanism is recursive: an integration body (attrset form) may itself contain
an `integrations` key, meaning "and additionally, when that feature is present
too".

```nix
flake.features.yazi.integrations.fish = {
  programs.yazi.enableFishIntegration = true;   # yazi ∧ fish
  integrations.direnv = { ... };                # yazi ∧ fish ∧ direnv
};
```

The base case — an integration with one feature — is byte-identical to the
singular form; conjunction is nesting the same field. There is no second
construct, no name lists, no reserved config keyword.

**Why it's unambiguous.** `integrations` can never be legitimate home-manager
config — no such option exists in a home — so an attrset body containing that
key always means nesting. The generator lifts nested nodes at generation time:
declarations are plain data at the flake layer, so this is metaprogramming
before any module eval, not a conditional import.

**Semantics.** Each lifted node normalizes internally to {when-set, config};
the gate is `mkIf` over the conjunction of the enable flags of self plus every
name on the path. Path order is irrelevant — `fish.direnv ≡ direnv.fish`.
Recorded growth path: because nodes normalize to a when-set, a future
standalone `when = [names]` field on features (fully conditional features)
would be the same machinery exposed, not a redesign.

**Validation.** Every nested key under any `integrations` is checked against
`flake.features` at declaration eval — typos fail loudly with a message naming
the key, same as single keys.

**Function-form bodies are leaves.** A body written as a function (it needs
`pkgs`/`config`/`lib`) is opaque to the generator and cannot carry nested
integrations; attempting it fails loudly — the un-lifted `integrations` key
flows into home config, where no such option exists, an immediate home-eval
error. Two documented workarounds:

- Conjunction commutes: nest in the other order so the function sits at a leaf
  (`integrations.direnv.integrations.fish = <fn>`).
- A compound may be declared from *any* participant's declaration — the gate
  always includes the declaring feature itself, so e.g. the fish feature
  declaring `integrations.yazi.integrations.direnv` produces the identical
  gate. The one truly stuck case (both singles function-valued on the same
  owner plus a compound between them) is escaped this way.

**Generator mechanics.** `lib.mkIf` can only gate a module's *config*, never a
whole module — `imports` and `options` are fixed before config eval. So the
generator imports each integration unconditionally, via a wrapper that
normalizes the deferredModule (calling it with module args if it's a function)
and wraps its contents in the conjunction gate, where each flag is read as
`present f = config.programs.${f}.enable or false`. The `or false` makes the
test safe when a named feature was never delivered to this home — its
generated toggle option wouldn't exist, and naive access would be an eval
error. Integration units ride both the install unit and the `-config` unit,
and like all shared config are boundary-wrapped to priority 900 (lists exempt)
— the user's own settings win.

**Universal enable flag.** Every feature delivered to a home stamps
`programs.<name>.enable = true` under its own name — home-manager's real option
where one exists, the generated toggle otherwise — now extended to *all*
features including roles: a config-carrying role's delivered unit carries the
toggle, and a pure-aggregation role's delivered unit is just the toggle set
true (a one-line tracer). Presence is thus one uniform concept: *delivered to
this home ∧ not opted out*. This makes `integrations.<key>` valid for any
declared feature, role or leaf, and generalizes opt-out:
`programs.desktop.enable = false` turns off the role's own config and anything
integrating against it — but **not** its members, which have their own flags
(member independence: a role key gates on the role's own unit, never on "all
members present").

**Enforced edge rules:**

- Integration modules are config-only: the generator rejects bodies containing
  `options` or `imports` keys with a loud eval error, since `mkIf` cannot gate
  them.
- An integration body must not set an enable flag it is gated on (self or any
  name on its path) — infinite recursion; generator assertion or documented
  rule.

### Open issues — do not treat the predicate above as final here

The user explicitly deferred the following; it needs a redesign before
implementation touches it:

- The exact validation rules around per-user import of members whose *install*
  is global-only but which carry per-user *config* — config-only delivery? hard
  error? host-dependent? Not settled.
- More broadly, the separation between the **config** portion and the **install**
  portion of a feature. The one predicate above covers the simple global-only
  case only; no implementer should treat it as the final word on this edge.
- How integrations behave between locally-installed (per-user) and
  globally-installed (system/cask) features. The gate reads "enabled in this
  home", so a feature installed only globally with no per-user face never sets
  a home flag, and integrations against it silently stay off. Whether that is
  the desired semantics — and whether integrations should be able to key on
  machine-level installation — is unresolved, and ties into the
  config-vs-install separation above.

### Consequences

- The host declaration's `baselines` field is **retired**: hosts list
  role-features in their global list (`globalPrograms`, renamed to match the
  features vocabulary — e.g. `globalFeatures`).
- Plumbing aspects that were never programs (secrets, network, printing,
  config-group) receive **minimal feature declarations** (marking classes
  `handWritten` where the aspect stays hand-authored), so roles import only
  features — one mechanism, no special cases.
- The content of `modules/host-config/roles/` migrates into the features tree
  (`modules/programs/` presumably becoming `modules/features/`).
- Opt-out stays uniform: `programs.<name>.enable = false;` in the user's folder.
- Unchanged: the one-channel home model, and the boundary priority wrapper
  (shared config lowered to 900, lists exempt).

## Plan

Deliberately deferred until the design round covering all change areas completes;
the plan will be written then via the writing-plans flow.

## Tasks

Deliberately deferred until the design round covering all change areas completes.
