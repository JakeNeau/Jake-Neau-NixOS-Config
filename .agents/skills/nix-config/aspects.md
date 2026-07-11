# Aspect design patterns

Reference for the recurring patterns shaping `flake.modules.<class>.<name>`
aspects. **Declaration** is this repo's own primary pattern — reach for it
first; the other seven come from the dendritic guide
(<https://github.com/Doc-Steve/dendritic-design-with-flake-parts>) and shape
the hand-written aspects beneath and beside the declarations. They are
suggestions, not rules, and a single feature often combines several. See
[`SKILL.md`](SKILL.md) for the mental model and the core rules these all obey.

Each section gives **What it is** (the aspect's structure), **Why use it** (the
problem it solves), and **Use it over others when** (how to pick it against
neighbouring patterns).

| Pattern | Reach for it when… |
| --- | --- |
| [Declaration](#declaration) | the thing is a program, a host, or a user — the default |
| [Simple](#simple) | a hand-written feature is independent and just configures something per class |
| [Inheritance](#inheritance) | you want to extend or modify an existing feature |
| [Conditional](#conditional) | parts of an aspect should depend on a condition (e.g. platform) |
| [Collector](#collector) | a feature's config is assembled from contributions by other features |
| [Constants](#constants) | you need shared values (or functions) across features and classes |
| [DRY](#dry) | you must reuse a value inside an "attrs-of-submodule" option |
| [Factory](#factory) | you want to stamp out features from parameters |

Quick decision guide:

- A program, host, or user → **Declaration** — always, before any hand-written shape.
- Just configuring something, no relationship to other features → **Simple**.
- Building on top of an existing feature → **Inheritance**.
- One aspect, but some lines only apply sometimes → **Conditional**.
- Many features each want to add to one shared thing → **Collector**.
- A plain value/function shared widely → **Constants** (function ⇒ a `flake.lib` library).
- A reusable chunk *inside* an attrs-of-submodule option → **DRY**.
- The same shape repeated with varying parameters → **Factory**.

---

## Declaration

**What it is:** a structured entry on one of the three declaration options —
`flake.programs.<name>`, `flake.hosts.<name>`, `flake.users.<name>` — from
which a generator (`modules/nix/flake-parts/declarations/`) produces the
aspects and flake outputs. You write data; the wiring is generated. Fields:
the [declaration schema reference](../../../docs/reference/declaration-schema.md);
what gets generated: [units](../../../docs/reference/generated-units.md) and
[host artifacts](../../../docs/reference/generated-host-artifacts.md).

**Why use it:** one declaration replaces the whole hand-written shape — the
per-class aspects, the platform split, the host wiring, the flake-output
boilerplate — and guarantees the invariants (one delivery channel per home,
user-overridable defaults, opt-out-able installs) by construction.

**Use it over others when:** the thing is a program, a host, or a user —
always. Hand-written patterns below are for what declarations don't cover:
services/daemons, machine-level plumbing, oddballs. A program that is *mostly*
declarable keeps its declaration and marks the hand-written class in
`handWritten` (yazi keeps a hand-written `nixos` portal aspect beside its
declaration).

```nix
# modules/programs/kubernetes/kubernetes.nix
{
  flake.programs.kubernetes = {
    install.linux = ["home"];
    install.macos = ["home"];
    hasEnableOption = false; # no HM module; the generator supplies the toggle
    packages = pkgs: [pkgs.kubectl pkgs.k9s];
  };
}
```

```nix
# modules/hosts/cedar/configuration.nix (the declaration half)
flake.hosts.cedar = {
  class = "darwin";
  system = "aarch64-darwin";
  users = ["jake.neau"];
  globalPrograms = ["ghostty" "firefox" "fastfetch"];
  installOverrides.firefox = "cask";
  baselines = ["role-desktop" "mac-app-util"];
};
```

```nix
# modules/users/jake.neau/jake.neau.nix (the declaration line)
flake.users."jake.neau".hosts.cedar.programs = ["kubernetes"];
```

## Simple

**What it is:** an independent `class` module per context, configuring directly.
Independent classes can share one file (handy for sharing partial config) or split
into `nixos.nix` / `darwin.nix` / etc.

**Why use it:** the lowest-ceremony way to turn a hand-written feature on — the
aspect's body does the enabling, with nothing to wire up beyond importing it.

**Use it over others when:** the feature stands alone *and* isn't a
program/host/user (those are Declarations). It doesn't build on another
feature (*Inheritance*) or vary by parameter (*Factory*). Most hand-written
features are Simple — start here, escalate only when a real relationship
appears.

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

## Inheritance

**What it is:** an aspect that `imports` one or more *parent* aspects in each class
and layers its own additions on top. This is how the layered roles
(`modules/host-config/roles/`) and hosts' quirks aspects are built.

**Why use it:** it lets you compose features instead of copy-pasting them — a
"desktop" is "default plus audio plus graphics plus a browser", expressed as
imports, so the parent stays the single source of truth.

**Use it over others when:** you want to *reuse and extend* an existing feature
as-is. Choose Collector instead when many features should contribute *into* one
shared aspect (the dependency points the other way); choose Factory when the thing
you'd be extending is really the same template stamped out with different values.

```nix
# modules/host-config/roles/desktop/desktop.nix (abridged)
{inputs, ...}: {
  flake.modules.nixos.role-desktop = {
    imports = with inputs.self.modules.nixos; [
      role-default # parent aspect
      # extensions:
      audio
      graphics
      niri-desktop
    ];
  };
}
```

> Remember the one-channel rule: a role's homeManager aggregate must never
> import a generated program unit that a host's `globalPrograms` or a user
> declaration already delivers — that would be a second channel into the home.

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
when you want one aspect that bends rather than several that duplicate. The same
shape works inside a program declaration's `config` field (ghostty's module
gates its macOS-only lines on `pkgs.stdenv.isDarwin`).

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

Illustrative (from the dendritic guide — no syncthing feature exists here):

```nix
# the collector
{
  flake.modules.nixos.syncthing = {
    services.syncthing.enable = true;
  };
}
```

```nix
# a contributor's own folder — it adds its device
{
  flake.modules.nixos.syncthing = {
    services.syncthing.settings.devices.homeserver.id = "VNV2XTI-…-Z35JUEG";
  };
}
```

## Constants

**What it is:** a `generic` aspect that declares an option and sets defaults,
imported high in the hierarchy so the values are readable everywhere. The live
instance is **host facts**: `flake.modules.generic.host-constants`
(`modules/host-config/host-constants/host-constants.nix`) declares the
`hostConstants` schema, `role-default` imports it into every class, hosts set
the values in their quirks aspect, and features read them back like any other
config option.

**Why use it:** it shares plain values (a hostname, a GPU vendor, "is this a
laptop") across features and classes through the normal module system — one
definition, type-checked reads, no threaded arguments or `specialArgs`.

**Use it over others when:** the shared thing is *data*, not config that accumulates
(that's Collector) and not a template (that's Factory). If the "constant" is
actually a *function*, it becomes a *library* aspect — the repo keeps such helpers
in `flake.lib`. For a value used in just one file, a plain `let … in` is lighter.

```nix
# declare (modules/host-config/host-constants/host-constants.nix, abridged)
{
  flake.modules.generic.host-constants = {lib, ...}: {
    options.hostConstants = {
      isLaptop = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
      # hostName, graphicsType, minecraftServer, …
    };
  };
}
```

```nix
# set (a host's quirks aspect)
flake.modules.darwin.cedar = {
  hostConstants.isLaptop = true;
  hostConstants.graphicsType = "apple";
};
```

```nix
# read (any feature, any class)
flake.modules.homeManager.fastfetch = {config, ...}: {
  # branch on config.hostConstants.isLaptop
};
```

**Delivery to homes:** standalone homes have no `osConfig`, so the hosts
generator injects a read-through of the *evaluated* system config into each
host's baseline — homes see exactly the facts the system eval resolved,
including facts set by imports. Declaring and reading stay exactly as above;
see [host facts](../../../docs/explanation/host-facts.md).

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
per-instance customizations with `lib.mkMerge`. The live instance is the user
factory (`modules/factory/user/user.nix`).

**Why use it:** when many features follow the same template (every user), a
factory captures the shape once so each instance is a call with arguments
rather than a hand-copied block.

**Use it over others when:** instances differ by *parameters* and share a template.
Factory supports parameters but not inheritance — the mirror image of DRY. If
instances instead share a fixed chunk you want to extend, use DRY; if there's only
one of the thing, a Simple aspect is enough.

```nix
# modules/factory/user/user.nix (abridged): account aspects + the HM aspect.
# Homes are standalone — the hosts generator stamps
# homeConfigurations."<user>@<host>" from the homeManager aspect; the factory
# does no home-manager wiring of its own.
{
  config.flake.factory.user = username: isAdmin: {
    nixos.${username} = {lib, pkgs, ...}: {
      users.users.${username} = {
        isNormalUser = true;
        home = "/home/${username}";
        extraGroups = ["networkmanager"] ++ lib.optionals isAdmin ["wheel"];
        shell = pkgs.fish;
      };
    };
    darwin.${username} = {lib, ...}: {
      # macOS owns the account; nix-darwin only records its home dir.
      users.users.${username}.home = "/Users/${username}";
      system.primaryUser = lib.mkIf isAdmin username;
    };
    homeManager.${username} = {config, pkgs, ...}: {
      home.username = username;
      # + the ~/.config/nix-config out-of-store symlink
    };
  };
}
```

```nix
# instantiate, then customize (modules/users/<user>/<user>.nix)
{inputs, lib, ...}: {
  flake.modules = lib.mkMerge [
    (inputs.self.factory.user "bob" true)
    {
      nixos.bob = {/* extra NixOS settings */};
      homeManager.bob = {/* per-user home config */};
    }
  ];
}
```

A factory may also return an **anonymous module** for one class, used directly in
`imports` (e.g. a `mount-cifs-nixos {host; resource; destination; …}` helper).
Prefer an attribute-set parameter when a function takes more than a couple of
arguments, so call sites stay readable.
