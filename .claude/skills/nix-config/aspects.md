# Aspect design patterns

Reference for the eight recurring patterns from the dendritic guide
(<https://github.com/Doc-Steve/dendritic-design-with-flake-parts>). Each is a way
to shape `flake.modules.<class>.<name>` aspects. They are suggestions, not rules,
and a single feature often combines several. See [`SKILL.md`](SKILL.md) for the
mental model and the core rules these all obey.

| Pattern | Reach for it when… |
| --- | --- |
| [Simple](#simple) | a feature is independent and just configures something per class |
| [Multi-Context](#multi-context) | a system (nixos/darwin) feature must also push home-manager config |
| [Inheritance](#inheritance) | you want to extend or modify an existing feature |
| [Conditional](#conditional) | parts of an aspect should depend on a condition (e.g. platform) |
| [Collector](#collector) | a feature's config is assembled from contributions by other features |
| [Constants](#constants) | you need shared values (or functions) across features and classes |
| [DRY](#dry) | you must reuse a value inside an "attrs-of-submodule" option |
| [Factory](#factory) | you want to stamp out features from parameters |

---

## Simple

**Use when:** a feature is optional, independent of other features, and just
needs configuring in one or more contexts.

Define a `class` module per context. Independent classes can live in one file
(handy for sharing partial config) or be split into `nixos.nix` / `darwin.nix` /
etc.

```nix
{
  flake.modules.nixos.basicPackages = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [git];
  };

  flake.modules.darwin.basicPackages = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [git];
  };

  flake.modules.homeManager.basicPackages = {
    programs = {
      # program configuration
    };
  };
}
```

## Multi-Context

**Use when:** a feature is used in *one* main context (e.g. NixOS or Darwin) but
must also configure a *nested* context (home-manager) as part of itself.

Create the main `class` module, plus an auxiliary module of the nested class, and
have the main module pull the auxiliary one in (e.g. via
`home-manager.sharedModules` or `home-manager.users.<name>`).

```nix
{inputs, ...}: {
  flake.modules.nixos.gnome = {
    home-manager.sharedModules = [inputs.self.modules.homeManager.gnome];
    # gnome configuration at the system level
  };

  flake.modules.homeManager.gnome = {
    # gnome configuration with home-manager's options (auxiliary module)
  };
}
```

The auxiliary `homeManager.gnome` starts "private" but is a normal named aspect,
so it can also be reused directly as a standalone home-manager feature later.

## Inheritance

**Use when:** you want to take an existing feature and extend or tweak it.

Import the parent aspect in each class and add your changes. This is how layered
"system types" and composed hosts/users are built.

```nix
{inputs, ...}: {
  flake.modules.nixos.system-desktop = {
    imports = with inputs.self.modules.nixos; [
      system-cli # parent aspect
      # extensions:
      browser
      printing
    ];
  };

  flake.modules.darwin.system-desktop = {
    imports = with inputs.self.modules.darwin; [
      system-cli # parent aspect
      browser
    ];
  };
}
```

> When combining Inheritance with Multi-Context, guard against importing the same
> module twice (e.g. don't add the same module to `home-manager.sharedModules`
> from both a parent and a child).

## Conditional

**Use when:** some parts of an aspect should apply only under a condition — most
often the platform, inside a cross-platform `homeManager` aspect.

Build the module body with `lib.mkMerge` and gate parts with `lib.mkIf`. Keep
**imports unconditional** — only content is conditional.

```nix
flake.modules.homeManager.office = {pkgs, lib, ...}:
  lib.mkMerge [
    {home.packages = with pkgs; [notesnook];} # all systems
    (lib.mkIf pkgs.stdenv.isLinux {
      home.packages = with pkgs; [libreoffice-qt6];
    })
    (lib.mkIf pkgs.stdenv.isDarwin {
      home.packages = with pkgs; [libreoffice-bin];
    })
  ];
```

## Collector

**Use when:** a feature's configuration is the sum of contributions made by
*other* features (so each contributor keeps its own data next to itself).

The collector defines its base config; each contributing feature adds to the
*same* named aspect. flake-parts merges the contributions. This is the one place
it's fine for a feature to define an aspect named after a *different* feature —
keep that contribution in a file named after the collector.

```nix
# modules/services/syncthing/syncthing.nix  — the collector
{
  flake.modules.nixos.syncthing = {
    services.syncthing.enable = true;
  };
}
```

```nix
# modules/hosts/homeserver/syncthing.nix  — a contributor adds its device
{
  flake.modules.nixos.syncthing = {
    services.syncthing.settings.devices.homeserver.id = "VNV2XTI-…-Z35JUEG";
  };
}
```

## Constants

**Use when:** you need to share constant values (or functions) across many
features, independent of class. Replaces older `specialArgs` plumbing.

Define a `generic` aspect that declares an option and sets it, then import that
aspect high in the hierarchy (e.g. into a default system type) so it's available
everywhere. Read the values like any other config option.

```nix
# define
{
  flake.modules.generic.systemConstants = {lib, ...}: {
    options.systemConstants = lib.mkOption {
      type = lib.types.attrsOf lib.types.unspecified;
      default = {};
    };
    config.systemConstants.adminEmail = "admin@test.org";
  };
}
```

```nix
# make available (import into each class of a base system type)
{inputs, ...}: {
  flake.modules.nixos.system-default.imports = [inputs.self.modules.generic.systemConstants];
  flake.modules.darwin.system-default.imports = [inputs.self.modules.generic.systemConstants];
  flake.modules.homeManager.system-default.imports = [inputs.self.modules.generic.systemConstants];
}
```

```nix
# use
flake.modules.nixos.homeserver = {config, ...}: {
  services.zfs.zed.settings.ZED_EMAIL_ADDR = [config.systemConstants.adminEmail];
};
```

> Alternatives for sharing values: a `let … in` in a single file, or an
> `options.<name>` on the feature read via `inputs.self.<name>`. If the "constant"
> is actually a function, this becomes a *library* aspect — the repo keeps such
> helpers in `flake.lib`.

## DRY

**Use when:** Simple won't fit because the attribute you want to reuse lives
inside an "attribute set of submodules" option (e.g.
`networking.interfaces.<name>…`). Define the reusable chunk under a **custom
class** and merge it in.

```nix
# define a reusable chunk under a new class
{
  flake.modules.networkInterface.subnet-A = {
    ipv4.routes = [{address = "192.168.2.0"; prefixLength = 24; via = "192.168.1.1";}];
  };
}
```

```nix
# reuse it (use lib.mkMerge, never //)
networking.interfaces."enp86s0" =
  with self.modules.networkInterface;
    lib.mkMerge [
      subnet-A
      {ipv4.addresses = [{address = "10.0.0.1"; prefixLength = 16;}];}
    ];
```

DRY supports inheritance (unlike Factory); Factory supports parameters (unlike
DRY).

## Factory

**Use when:** you want to generate features from parameters — e.g. every user, or
every CIFS mount, follows the same template.

Store factory functions in the `flake.factory` library, then call them to mint
named aspects (merge customizations with `lib.mkMerge`).

```nix
# a factory function in the library
{self, ...}: {
  config.flake.factory.user = username: isAdmin: {
    nixos.${username} = {lib, pkgs, ...}: {
      users.users.${username} = {
        isNormalUser = true;
        extraGroups = lib.optionals isAdmin ["wheel"];
        shell = pkgs.zsh;
      };
      home-manager.users.${username}.imports = [self.modules.homeManager.${username}];
    };
    darwin.${username} = {lib, pkgs, ...}: {
      users.users.${username}.shell = pkgs.zsh;
      system.primaryUser = lib.mkIf isAdmin username;
      home-manager.users.${username}.imports = [self.modules.homeManager.${username}];
    };
    homeManager.${username}.home.username = username;
  };
}
```

```nix
# instantiate, then customize
{self, lib, ...}: {
  flake.modules = lib.mkMerge [
    (self.factory.user "bob" true)
    {
      nixos.bob = {/* extra NixOS settings */};
      darwin.bob = {/* extra Darwin settings */};
    }
  ];
}
```

A factory may also return an **anonymous module** for one class, used directly in
`imports` (e.g. a `mount-cifs-nixos {host; resource; destination; …}` helper).
Prefer an attribute-set parameter when a function takes more than a couple of
arguments, so call sites stay readable.
