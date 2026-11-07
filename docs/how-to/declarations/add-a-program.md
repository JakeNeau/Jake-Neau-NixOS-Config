# Add a program

Declare a program once; the generator produces the installable units. Full
field semantics: the
[declaration schema reference](../../reference/declaration-schema.md); what gets
generated: the [generated-units reference](../../reference/generated-units.md).

## 1. Write the declaration

Create `modules/programs/<name>/<name>.nix`:

```nix
{
  flake.programs.<name> = {
    # Install ways. The platform block's ways come first, then shared's.
    #   shared: "home" (per-user HM) and/or "custom" (systemConfig installs it)
    #   linux:  "home", "system" (NixOS system package), and/or "custom"
    #   macos:  "home", "cask" (homebrew cask, machine-wide), and/or "custom"
    shared.install = [ "home" ];

    # HM default config, in any module form (attrset, full module, or
    # function). Optional. Users override any of it by plain assignment in
    # their own folder.
    shared.config = {
      programs.<name>.settings = { ... };
    };
  };
}
```

Field choices:

- **Different ways per platform?** Set `linux.install` and `macos.install`
  instead of `shared.install` (see `modules/programs/ghostty/ghostty.nix`,
  which installs per-user on Linux and from the cask on macOS).
- **No home-manager module for this program?** Set
  `hasEnableOption = false;`. The generator then declares the
  `programs.<name>.enable` toggle itself and installs `pkgs.<name>` behind
  it. If the package attribute differs from the name, or the program needs
  several packages, add `shared.packages = pkgs: [pkgs.foo pkgs.bar];` (see
  `modules/programs/kubernetes/kubernetes.nix`). Put a platform's own
  packages in `linux.packages` or `macos.packages` (see
  `modules/programs/openpencil/openpencil.nix`).
- **Home-manager module under another name, and only machine-wide ways?**
  Set `hasEnableOption = false;`. The default would set
  `programs.<name>.package = null`, an option that does not exist. Without a
  `"home"` way, the generator declares no `programs.<name>` toggle. Write
  `shared.config` against the real module instead. Enable it, and set
  `package = null` so it configures the machine-wide install (see
  `modules/programs/ungoogled-chromium/ungoogled-chromium.nix`, which
  configures `programs.chromium`).
- **Needs a daemon or other machine-level config?** Put that config in
  `linux.systemConfig` beside a `"system"` way, or in `macos.systemConfig`
  beside a `"cask"` way. The generated `nixos.<name>` or `darwin.<name>`
  unit imports it (see `modules/programs/mullvad-vpn/mullvad-vpn.nix`, whose
  `macos.systemConfig` sits beside its cask).
- **Installed by its own system module?** Declare the `"custom"` way and
  set `systemConfig` on that platform. The generator installs nothing
  itself. The `systemConfig` installs the program, for example through a
  NixOS `programs.<name>.enable` module (see
  `modules/programs/steam/steam.nix`).
- **Should bypass the VPN?** Set `excludeFromVpn = true;`. See [VPN
  exclusion and Mullvad split
  tunneling](../../explanation/mullvad-split-tunneling.md).
- **A hand-written aspect of the same name must survive?** Suppress that
  class with e.g. `handWritten = ["nixos"];` so the generator emits nothing
  for it — no unit, no tombstone (see `modules/programs/yazi/yazi.nix`, whose
  NixOS portal aspect is hand-written). A class can't be both declared and
  hand-written; incoherent combinations throw at evaluation with the fix
  named.
- **Platform-specific config?** Put it in `linux.config` or `macos.config`.
  The generator applies it only on that platform, so the module needs no
  platform check (see `modules/programs/ghostty/ghostty.nix`). Keep imports
  in `shared.config`, because a platform block may not import modules.

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
  `installOverrides.<name> = "cask";` line beside it. An override may also
  name `"custom"`.
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
