# Host facts

Why `hostConstants` exists, how its values reach standalone homes, and
what set-by-import means. The option schema lives in
`modules/host-config/host-constants/host-constants.nix`; where the
read-through is stamped: [generated host
artifacts](../reference/generated-host-artifacts.md).

## The Constants pattern

A host states what it *is* — `hostConstants.isLaptop = true`,
`hostConstants.graphicsType = "amd"` — and features branch on the fact,
instead of minting per-variant aspects per feature. The schema is declared
once (`flake.modules.generic.host-constants`) and readable from any
feature in any class: system config and home-manager alike. Hosts only set
values.

## The read-through: why and how

Standalone homes broke the old delivery. With home-manager as a system
module, facts flowed in via `sharedModules` pushes or `osConfig`; on the
standalone path neither exists — a home eval is its own module system with
no system config in scope.

The hosts generator therefore injects one module into each host's
generated baseline:

```nix
hostConstants =
  inputs.self.<class>Configurations.<host>.config.hostConstants;
```

a lazy read-through of the *evaluated* system config. Homes see exactly
the facts the system eval resolved — including facts set by imports —
because the values are read out of the finished eval rather than
re-declared.

Trade-offs, accepted deliberately:

- A home eval now pulls (part of) the host's system eval, so `hr` gets a
  few seconds slower. Eval-only — nothing is built.
- A non-evaluating system config blocks home rebuilds. Mitigated: `nr`
  verifies every system config and every home before anything lands.

One boundary: the read-through delivers *values* into modules; it cannot
serve *routing*. Install-way selection happens at the flake level, before
any module eval, so it can never branch on a `hostConstants` fact — see
the rejected shapes in [install-way
resolution](install-way-resolution.md).

## Set-by-import

Facts keep set-anywhere semantics: values are assigned inside system
module eval — by host aspects, or by feature bundles. That second form is
the interesting one: a feature that sets its own fact beside its own
enable makes *importing the feature* mean something.

The worked example is minecraft
(`modules/nix/tools/nix-minecraft/nix-minecraft.nix`):

```nix
services.minecraft-servers.enable = true;
hostConstants.minecraftServer = true;
```

The enable and the fact sit beside each other in the feature itself, so
importing nix-minecraft *means* "this host runs a minecraft server" — the
two can never drift apart, and readers of the fact (fish's `mc-*` helpers,
branching from standalone homes via the read-through) stay in lockstep
with the service by construction. redwood imports the feature and keeps
only the server definitions; the meaning travels with the import.
