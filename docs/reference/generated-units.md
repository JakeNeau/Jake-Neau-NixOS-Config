# Generated units reference

The `flake.modules` units the programs generator
(`modules/nix/flake-parts/declarations/programs.nix`) emits for each
`flake.programs.<name>` declaration. The declaration's fields:
[declaration schema reference](declaration-schema.md). Why the units carry
plain config: [the framework's
why](../explanation/declaration-framework.md).

## homeManager.\<name\>

The per-user install unit, generated when any `install.<platform>` list
contains `"home"`. It:

- imports the declaration's `config` module;
- gates its content (never its imports) on the platforms that declare
  `"home"`, via `pkgs.stdenv.isLinux` / `isDarwin`;
- sets `programs.<name>.enable = true` plainly — the boundary wrapper
  lands it at priority 900 at host stamping, so a user's plain
  `programs.<name>.enable = false;` (priority 100) wins;
- when `hasEnableOption = false`, declares the `programs.<name>.enable`
  toggle itself (`lib.mkEnableOption`) and installs the declaration's
  `packages` behind it via `home.packages`, marked `lib.mkOverride 100` —
  an explicit marker the boundary wrapper leaves alone, so the list
  concatenates with a user's own `home.packages` like an upstream
  home-manager module's would.

The install channel is never a bare `home.packages` contribution: a
900-stamped list would be discarded wholesale by a user's plain
`home.packages` assignment.

## homeManager.\<name\>-config

The config-only unit — for users on machines where the install is
global/system-level; the hosts generator routes it into the baseline in
place of the full unit (see [generated host
artifacts](generated-host-artifacts.md)).

- When `hasEnableOption = true` **and** the declaration has a true-system
  way (`"system"` on Linux or `"cask"` on macOS): the declaration's
  `config` plus `programs.<name>.package = null` — home-manager's
  configure-without-installing mode, so enabling the program configures
  the system-installed app instead of double-installing the nix package.
- Otherwise: the declaration's `config`, verbatim.

## nixos.\<name\> / darwin.\<name\>

True-system install units, generated only for programs that declare one:

- `nixos.<name>` — when `install.linux` contains `"system"`:
  `environment.systemPackages = [pkgs.<name>]`.
- `darwin.<name>` — when `install.macos` contains `"cask"`:
  `homebrew.casks = ["<name>"]`.

## Tombstones

Every plausible-but-unsupported unit is generated as a module carrying a
failing assertion that names the program and the fix, so importing it
fails readably instead of with an "attribute ... missing" error:

- `homeManager.<name>` when no platform declares `"home"`;
- `nixos.<name>` when `install.linux` lacks `"system"`;
- `darwin.<name>` when `install.macos` lacks `"cask"`.

## Class suppression

A class listed in the declaration's `handWritten` field gets *nothing* —
no unit, no tombstone. `flake.modules.<class>.<name>` merges all
definitions of a name, so a generated tombstone would otherwise poison a
substantive hand-written aspect of the same name (yazi's portal machinery,
`modules/programs/yazi/yazi.nix`).

## Per-user opt-out

Generated installs are defaults, not mandates: a user opts out with
`programs.<name>.enable = false;` in their own folder
(`modules/users/<user>/`), which beats the wrapped default at priority
100 vs 900.

Documented edge — yazi on Linux: opting out also releases the
`inode/directory` file-type default (the claim is conditioned on the
enable switch), but the machine-global FileChooser → termfilechooser
portal route (the hand-written `nixos.yazi` aspect) assumes yazi's
wrapper, so an opted-out user flips their portal route back with a
one-line per-user override.
