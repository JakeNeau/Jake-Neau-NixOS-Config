# Add a per-user program

Give one user a program — on all their machines or on one — without touching
any host's `globalPrograms`. The program must have a `flake.programs`
declaration ([Add a program](add-a-program.md)).

## The one-liner

In the user's folder (`modules/users/<user>/`), on their `flake.users`
declaration:

```nix
# on one host only (the user must be listed in flake.hosts.<host>.users):
flake.users."<user>".hosts.<host>.programs = ["kubernetes"];

# or on every machine the user is on:
flake.users."<user>".programs = ["yazi"];
```

Live example: `modules/users/jake.neau/jake.neau.nix` puts kubernetes on
cedar only.

Then stage (if the file is new) and dry-build the affected home:

```sh
nix build '.#homeConfigurations."<user>@<host>".activationPackage' --no-link
```

## When an entry filters vs throws

User entries are per-user-only: they resolve to the per-user ("home") install
way or drop out — they never cause a system install. Per (program, host):

| Situation | `programs` (all hosts) | `hosts.<h>.programs` (one host) |
|---|---|---|
| Per-user way declared for the host's platform, no override | delivered | delivered |
| Host's `installOverrides` forces a system way (e.g. cedar's firefox cask) | **filters silently** — the host installs it globally; the baseline carries the `-config` unit | **filters silently** |
| No per-user way on this host's platform (but one exists elsewhere) | **filters silently** — the program appears on the user's other platforms | **throws** — deliver it via the host's `globalPrograms` or add a `"home"` way |
| No per-user way on *any* platform | **throws** — it can never be a per-user program | **throws** |
| Host not in `flake.hosts.<h>.users` for this user | n/a | **throws** — list the user on the host or drop the entry |

Every throw happens at evaluation time (so the dry-build catches it) and
names the user, the program, and the fix. Rationale for the
filter-vs-throw split:
[Install-way resolution](../../explanation/install-way-resolution.md).
