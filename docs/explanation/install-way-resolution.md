# Install-way resolution

Why install ways are resolved per (program, host), why the override lives
on the host, and why user entries filter rather than force installs. The
mechanics in recipe form: [Add a
per-user program](../how-to/declarations/add-a-per-user-program.md); the field
descriptions: [declaration schema
reference](../reference/declaration-schema.md).

## Per (program, host), not per platform

A program declares the *set* of ways it supports per platform
(`install.linux`, `install.macos`). Which way actually applies is a fact
about a machine, not a platform: cedar takes the firefox cask because
*cedar's* org SSO breaks the nix package, while aspen — same platform —
takes the home-manager install. So resolution happens per (program, host):

- the host's `installOverrides.<program>`, if set, wins (and must name a
  declared way, or declaration eval throws);
- otherwise per-user `"home"` wins when declared — home-manager installs
  everything it possibly can;
- otherwise the platform's sole system way.

## Why the override reroutes both halves

For a `globalPrograms` entry, the override reroutes the program's two
halves together, by construction: the system part into the host's
generated host-config aspect, the host's users onto the `-config` unit
through the baseline. One line can never yield a cask without config, or
config plus a double install — the failure modes of coordinating two
separate moves by hand.

## Why the override lives on the host

What the override encodes is a machine fact, and a cask is inherently
machine-global. A program-level knob would make the program name hosts
(violating "programs never name users/hosts"); a user-level knob would
misrepresent a global install as per-user.

## User entries: filter, don't force

User declarations are per-user-only: they resolve to per-user home-manager
units or produce nothing — a user entry can never cause a system install.
When resolution routes a requested program to a system install, the entry
**filters out** rather than throwing, because the request is *satisfied*,
not contradicted: if the host actually installs the program (a
`globalPrograms` entry), the user rides that install and picks up the
`-config` unit through the baseline like every other user on the host; if
the host doesn't install it, the user simply doesn't have it there — which
is the correct meaning of "a user cannot force a machine-global install".

The two user lists differ in strictness because they differ in intent:

- `programs` (all-hosts) filters silently per host — a program with a
  per-user way on Linux but not macOS shows up on the user's Linux hosts
  only. One coherence check remains: a program with no per-user way on
  *any* platform can never be a per-user program, so listing it throws.
- `hosts.<h>.programs` named that host deliberately, so a program with no
  per-user way for that host's platform contradicts the request and
  throws. The override-covered case (a home way exists, the host forces
  the system install) still filters — same-program-covered reasoning as
  above.

One edge worth knowing: an `installOverrides` entry filters user requests
even when the program is *not* in the host's `globalPrograms`. The
override says "on this host, this program installs the system way"; the
user channel can't deliver that way, and no host channel is asked to — so
the user's request filters out with nothing delivering the program. The
fix is the same line the override anticipates: list the program in the
host's `globalPrograms`.

## Rejected shapes

Three alternatives were considered for way selection and rejected; they
are recorded because each fails for a durable structural reason, not a
fixable detail:

- **Branching the generated unit on a `hostConstants` fact.** The
  flake-level generator cannot read module-eval constants at routing time
  — resolution happens before any module eval (see [host
  facts](host-facts.md) for the same boundary from the other side). And
  the two coordinated moves it requires (import the cask unit, set the
  fact) drift silently into a double install.
- **Separate `firefox`/`firefox-cask` declarations.** Splits one program's
  identity in two and duplicates its config.
- **Annotated list entries (`"firefox:cask"` in `globalPrograms`).**
  Buries the machine fact inside one channel's list, where
  user-declaration resolution — which must honor the same override to know
  when to filter — can't see it.
