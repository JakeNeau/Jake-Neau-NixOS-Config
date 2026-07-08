# The standalone home model

Why every user's home is a standalone `homeConfigurations."<user>@<host>"`
output, and what follows from that. The doing lives in [Rebuild your
home](../how-to/rebuild-your-home.md); the composition of a stamped home:
[generated host artifacts](../reference/generated-host-artifacts.md).

## Why one channel

Home-manager used to run as a system module here, and config reached a
home through several channels at once: user aspect imports,
`home-manager.sharedModules` pushes, host-level reach-ins. That coupling
had two costs. A user could not apply their own home without a system
rebuild — the home was a byproduct of the host's eval. And multiple
channels invite double delivery: `flake.modules` merges same-name
definitions and list options concatenate, so a program arriving twice
silently duplicates its list entries.

The framework removes the system module entirely and makes exactly one
channel deliver config to a home: the standalone output, composed at
stamping from the user's aspect, the host's baseline, and the user's
declared program units. A user rebuilds their own home with `hr`, no
system rebuild and no root involved; double delivery is structurally
impossible. (See [the framework's why](declaration-framework.md) for the
principle in context.)

## Consequences

The system module did quiet work that standalone homes must replace or
accept losing:

- **Each home evaluates its own nixpkgs.** `useGlobalPkgs` is gone, so the
  shared nixpkgs policy — allowUnfree, the NUR overlay — must arrive
  explicitly. That is the [common nixpkgs
  module](../reference/common-nixpkgs.md), imported into every stamped
  home.
- **Packages land in `~/.nix-profile`,** not the system module's
  `useUserPackages` location `/etc/profiles/per-user/<user>`. Anything
  that assumed the old path — PATH entries, fish's vendor-dir plugin
  pickup — follows the profile.
- **`backupFileExtension` is lost,** so every documented switch command
  carries `-b backup`: without it, a clashing pre-existing file aborts the
  switch instead of being backed up aside. `hr` bakes the flag in.
- **`nr` verifies all homes but reactivates only the invoker's.** The
  rebuild flow evaluates every `homeConfigurations."<user>@<host>"` output
  before committing, so no user's next switch can hit a broken config —
  but activation is each user's own act: `nr` finishes by calling `hr` for
  the invoking user, and other users run `hr` themselves when they choose.
- **The `home-manager` CLI must come from somewhere.** The common nixpkgs
  module sets `programs.home-manager.enable = true`, so every home ships
  the CLI it switches itself with (and the first-ever switch bootstraps
  via `nix run`, per the [bootstrap
  guide](../how-to/bootstrap-machine.md)).
