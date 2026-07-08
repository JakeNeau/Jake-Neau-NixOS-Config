# Add a program

Declare a program once; the generator produces the installable units. Full
field semantics: the
[declaration schema reference](../reference/declaration-schema.md); what gets
generated: the [generated-units reference](../reference/generated-units.md).

## 1. Write the declaration

Create `modules/programs/<name>/<name>.nix`:

```nix
{
  flake.programs.<name> = {
    # Install ways per platform:
    #   linux: "home" (per-user HM) and/or "system" (NixOS system package)
    #   macos: "home" (per-user HM) and/or "cask" (homebrew cask, machine-global)
    install.linux = ["home"];
    install.macos = ["home"];

    # Shared HM default config, in any module form (attrset, full module,
    # or function). Optional. Users override any of it by plain assignment
    # in their own folder.
    config = {
      programs.<name>.settings = { ... };
    };
  };
}
```

Field choices:

- **No home-manager module for this program?** Set
  `hasEnableOption = false;` — the generator declares the
  `programs.<name>.enable` toggle itself and installs `pkgs.<name>` behind
  it. If the package attribute differs from the name (or several packages are
  needed), add `packages = pkgs: [pkgs.foo pkgs.bar];` (see
  `modules/programs/kubernetes/kubernetes.nix`).
- **A hand-written aspect of the same name must survive?** Suppress that
  class with e.g. `handWritten = ["nixos"];` so the generator emits nothing
  for it — no unit, no tombstone (see `modules/programs/yazi/yazi.nix`, whose
  NixOS portal aspect is hand-written). A class can't be both declared and
  hand-written; incoherent combinations throw at evaluation with the fix
  named.
- **Platform-specific config?** Make `config` a module function and gate on
  `pkgs.stdenv.isLinux`/`isDarwin` (see
  `modules/programs/ghostty/ghostty.nix`).

## 2. Stage it

```sh
git add modules/programs/<name>/
```

Flake evaluation ignores untracked files.

## 3. Request it somewhere

A declaration alone installs nothing. Either:

- **Every user on a host:** add the name to that host's `globalPrograms`
  list in `modules/hosts/<host>/configuration.nix`. If the host should take a
  non-default way (e.g. the cask instead of the per-user install), add an
  `installOverrides.<name> = "cask";` line beside it.
- **One user:** a `flake.users` entry — see
  [Add a per-user program](add-a-per-user-program.md).

## 4. Dry-build

```sh
nix flake check
nix build .#darwinConfigurations.<host>.system --no-link   # each affected mac
nix build '.#homeConfigurations."<user>@<host>".activationPackage' --no-link
```

(NixOS hosts: `nix build
.#nixosConfigurations.<host>.config.system.build.toplevel --no-link`.)
