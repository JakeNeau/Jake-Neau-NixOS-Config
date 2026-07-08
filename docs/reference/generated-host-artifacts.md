# Generated host artifacts reference

What the hosts generator
(`modules/nix/flake-parts/declarations/hosts.nix`) stamps for each
`flake.hosts.<name>` declaration. The declaration's fields:
[declaration schema reference](declaration-schema.md). How install ways
are chosen: [install-way
resolution](../explanation/install-way-resolution.md).

## flake.modules.\<class\>.\<host\>-host-config

The host's generated OS-level aspect, merged into the system alongside the
hand-written `flake.modules.<class>.<host>` aspect. It imports:

- each listed user's factory-produced account aspect
  (`flake.modules.<class>.<user>`) — account *definition* stays in the
  factory, *placement* is the declaration's;
- the system unit (`nixos.<p>` / `darwin.<p>`) of every `globalPrograms`
  entry whose resolved way is not `"home"`.

## flake.modules.homeManager.\<host\>-baseline

The per-host baseline aspect every listed user's home imports. It imports:

- the `baselines` aggregates (`flake.modules.homeManager.<name>` for each
  listed name);
- each global program's home-manager half: the full `homeManager.<p>` unit
  when the resolved way is `"home"`, the `homeManager.<p>-config` unit
  otherwise;
- the `hostConstants` read-through module.

## The hostConstants read-through module

An inline module in the baseline setting

```nix
hostConstants =
  inputs.self.<nixosConfigurations|darwinConfigurations>.<host>.config.hostConstants;
```

(output attribute chosen by the declaration's `class`), so homes see
exactly the facts the host's system eval resolved — neither
`sharedModules` nor `osConfig` exists on the standalone path. Why this
shape and its trade-offs: [host facts](../explanation/host-facts.md).

## nixosConfigurations.\<host\> / darwinConfigurations.\<host\>

The system output, per the declaration's `class`:
`inputs.nixpkgs.lib.nixosSystem` or `inputs.nix-darwin.lib.darwinSystem`
over three modules — the hand-written `flake.modules.<class>.<host>`
aspect, the generated `<host>-host-config` aspect, and
`nixpkgs.hostPlatform = lib.mkDefault <system>`.

## homeConfigurations."\<user\>@\<host\>"

One output per listed user, via
`inputs.home-manager.lib.homeManagerConfiguration` with
`pkgs = inputs.nixpkgs.legacyPackages.<system>`. Its modules:

- `flake.modules.homeManager.<user>` — the user's own aspect,
  **unwrapped**: it is the overriding layer;
- wrapped at priority 900 by the boundary priority wrapper:
  the `<host>-baseline` aspect, the
  [common nixpkgs module](common-nixpkgs.md)
  (`flake.modules.homeManager.common-nixpkgs`), and the user-declaration
  units resolved for this (user, host) pair
  (`flake.lib.homeUnits`, from
  `modules/nix/flake-parts/declarations/users.nix`).

The wrapper's mechanics and rationale: [the framework's
why](../explanation/declaration-framework.md).
