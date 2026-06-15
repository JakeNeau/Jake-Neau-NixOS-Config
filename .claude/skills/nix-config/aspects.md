# Aspect design patterns

Reference for the eight recurring patterns from the dendritic guide
(<https://github.com/Doc-Steve/dendritic-design-with-flake-parts>) — ways to shape
`flake.modules.<class>.<name>` aspects. They are suggestions, not rules, and a
single feature often combines several. See [`SKILL.md`](SKILL.md) for the mental
model and the core rules these all obey.

Each section gives **What it is** (the aspect's structure), **Why use it** (the
problem it solves), and **Use it over others when** (how to pick it against
neighbouring patterns).

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

Quick decision guide:

- Just configuring something, no relationship to other features → **Simple**.
- Need to also reach into a nested context (home-manager from a system) → **Multi-Context**.
- Building on top of an existing feature → **Inheritance**.
- One aspect, but some lines only apply sometimes → **Conditional**.
- Many features each want to add to one shared thing → **Collector**.
- A plain value/function shared widely → **Constants** (function ⇒ a `flake.lib` library).
- A reusable chunk *inside* an attrs-of-submodule option → **DRY**.
- The same shape repeated with varying parameters → **Factory**.

---

## Simple

**What it is:** an independent `class` module per context, configuring directly.
Independent classes can share one file (handy for sharing partial config) or split
into `nixos.nix` / `darwin.nix` / etc.

**Why use it:** the lowest-ceremony way to turn a feature on — the aspect's body
does the enabling, with nothing to wire up beyond importing it.

**Use it over others when:** the feature stands alone. It doesn't reach into a
nested context (*Multi-Context*), build on another feature (*Inheritance*), or vary
by parameter (*Factory*). Most features are Simple — start here, escalate only when
a real relationship appears.

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

**What it is:** a main `class` module (e.g. NixOS or Darwin) plus an auxiliary
module of a *nested* class (home-manager), where the main module pulls the
auxiliary one in (via `home-manager.sharedModules` or `home-manager.users.<name>`).

**Why use it:** some configuration only makes sense from the system side but must
also drive per-user home-manager settings as one indivisible feature — so the two
halves travel together and turn on with a single import.

**Use it over others when:** you must configure two *contexts at once* from one
feature. If the home-manager part is genuinely standalone, leave it a Simple
`homeManager` aspect; reach for Multi-Context only when a system aspect owns and
must activate the nested config.

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

The auxiliary `homeManager.gnome` starts "private" but is a normal named aspect, so
it can also be reused directly as a standalone home-manager feature later.

## Inheritance

**What it is:** an aspect that `imports` one or more *parent* aspects in each class
and layers its own additions on top. This is how layered "system types" and
composed hosts/users are built.

**Why use it:** it lets you compose features instead of copy-pasting them — a
"desktop" is "cli plus a browser plus printing", expressed as imports, so the
parent stays the single source of truth.

**Use it over others when:** you want to *reuse and extend* an existing feature
as-is. Choose Collector instead when many features should contribute *into* one
shared aspect (the dependency points the other way); choose Factory when the thing
you'd be extending is really the same template stamped out with different values.

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

**What it is:** a single aspect whose body is built with `lib.mkMerge`, gating parts
with `lib.mkIf` — most often on the platform, inside a cross-platform `homeManager`
aspect. **Imports stay unconditional; only content is conditional.**

**Why use it:** one feature can serve every context while still adapting the details
(a different package name per OS) — without splitting into near-duplicate aspects or
breaking evaluation with a conditional import.

**Use it over others when:** the variation is *within* one aspect and switches on a
runtime-detectable condition (`pkgs.stdenv.isLinux/isDarwin`). If the contexts are
genuinely separate modules, prefer Simple's per-class split; reach for Conditional
when you want one aspect that bends rather than several that duplicate.

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

**What it is:** a base aspect (the *collector*) plus other features that each add to
that *same* named aspect; flake-parts merges the contributions. This is the one
place it's fine for a feature to define an aspect named after a *different* feature
— keep that contribution in a file named after the collector.

**Why use it:** it keeps each contributor's data next to the contributor (a host
declares its own syncthing device id), instead of forcing one central file to know
everything that feeds it.

**Use it over others when:** the final config is the *sum of many features'
contributions* and you want data to live with its owner. This is the inverse of
Inheritance: there a child reaches out to pull parents in; here contributors push
into a shared aspect. Use Constants instead when what's shared is a single value
rather than accumulated config.

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

**What it is:** a `generic` aspect that declares an option and sets it, imported
high in the hierarchy (e.g. into a default system type) so the value is available
everywhere. Read it back like any other config option. Replaces older `specialArgs`
plumbing.

**Why use it:** it shares plain values (an admin email, a domain) across features
and classes through the normal module system, so there's one definition and
type-checked reads instead of threaded arguments.

**Use it over others when:** the shared thing is *data*, not config that accumulates
(that's Collector) and not a template (that's Factory). If the "constant" is
actually a *function*, it becomes a *library* aspect — the repo keeps such helpers
in `flake.lib`. For a value used in just one file, a plain `let … in` is lighter.

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
> `options.<name>` on the feature read via `inputs.self.<name>`.

## DRY

**What it is:** a reusable config chunk defined under a **custom module class**,
merged into an "attribute set of submodules" option (e.g.
`networking.interfaces.<name>…`) with `lib.mkMerge`.

**Why use it:** Simple can't help when the value you want to reuse lives *inside* a
per-instance submodule — there's no top-level option to share. A custom-class aspect
gives that chunk a name so several instances can pull it in.

**Use it over others when:** you're factoring out a repeated fragment *within*
attrs-of-submodule options and the fragment itself benefits from being extended. DRY
supports inheritance but not parameters; if each instance differs by an argument
rather than a fixed shared chunk, use **Factory** instead.

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

## Factory

**What it is:** a function in the `flake.factory` library that, given parameters,
returns named aspects across classes. Call it to mint features, then merge
per-instance customizations with `lib.mkMerge`.

**Why use it:** when many features follow the same template (every user, every CIFS
mount), a factory captures the shape once so each instance is a call with arguments
rather than a hand-copied block.

**Use it over others when:** instances differ by *parameters* and share a template.
Factory supports parameters but not inheritance — the mirror image of DRY. If
instances instead share a fixed chunk you want to extend, use DRY; if there's only
one of the thing, a Simple aspect is enough.

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
