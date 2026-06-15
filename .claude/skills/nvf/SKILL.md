---
name: nvf
description: How to configure Neovim with nvf in this repo using the standalone flake method (nvf.lib.neovimConfiguration), which builds Neovim as a self-contained, portable package exposed as a flake output instead of a NixOS/home-manager module. Use when adding, editing, or migrating Neovim configuration — plugins, languages, LSP, keymaps, theme/options — or when wiring the built editor into a host.
---

# Configuring Neovim with nvf (standalone flake method)

[nvf](https://github.com/NotAShelf/nvf) is a modular, distro-agnostic Neovim
configuration framework for Nix. It exposes the same option set three ways: a
NixOS module, a home-manager module, and a **standalone builder** that produces a
self-contained Neovim *package*.

**This repo uses — and this skill documents — the standalone builder.** Jake
intends to configure Neovim as its own flake, so prefer `nvf.lib.neovimConfiguration`
over the `programs.nvf` NixOS/home-manager modules. (`configuration.nix` still
carries old `programs.nvf` module config; treat that as the thing being migrated,
not the pattern to copy — see *Migrating* below.)

## Why "its own flake"

The builder turns your Neovim config into an ordinary derivation, which means:

- **Portable & distro-agnostic.** The same package runs on NixOS, nix-darwin, or
  any machine with Nix — `nix run` it anywhere, no system module required.
- **Decoupled from system rebuilds.** Iterate with `nix build` / `nix run`, no
  `darwin-rebuild` / `nixos-rebuild` cycle.
- **Shareable.** A public flake output lets others (or other repos) consume your
  exact editor in one line.
- **Composable.** The package drops into `environment.systemPackages`,
  `home.packages`, or any other package list when you do want it on a host.

## The builder: `nvf.lib.neovimConfiguration`

```nix
nvf.lib.neovimConfiguration {
  pkgs = <a nixpkgs instance for the target system>;   # required
  modules = [ <nvf modules> ];                          # your config.vim = { … }
  extraSpecialArgs = { … };                             # optional: extra args passed to modules
}
```

It returns an attrset:

| attribute | what it is |
|-----------|------------|
| `neovim`  | **the built Neovim package** — this is what you expose / install |
| `config`  | the fully-evaluated configuration |
| `options` | the options that were available to configure |
| `pkgs`    | the package set used to evaluate the modules |

You almost always want `.neovim`.

## A complete standalone flake

A minimal self-contained `flake.nix` that builds Neovim and makes it runnable
with `nix run`:

```nix
{
  description = "Jake's Neovim, built with nvf";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nvf.url = "github:notashelf/nvf";
    # Make nvf build against the same nixpkgs as the rest of the system:
    nvf.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {nixpkgs, nvf, ...}: let
    system = "aarch64-darwin"; # or x86_64-linux, etc.
    pkgs = nixpkgs.legacyPackages.${system};

    neovim =
      (nvf.lib.neovimConfiguration {
        inherit pkgs;
        modules = [./config.nix]; # the file below, holding config.vim = { … }
      })
      .neovim;
  in {
    packages.${system} = {
      inherit neovim;
      default = neovim;
    };

    # Lets `nix run` launch the editor directly.
    apps.${system}.default = {
      type = "app";
      program = "${neovim}/bin/nvim";
    };
  };
}
```

```sh
nix run .#         # launch this Neovim
nix build .#neovim # just build the package (result/bin/nvim)
```

The `modules` list can be inline attrsets or files; splitting `config.vim` into a
`config.nix` keeps the flake small.

## Writing config: the `vim` namespace

Every option lives under **`vim`** (write it as `config.vim` inside a module). A
module file looks like:

```nix
# config.nix
{pkgs, ...}: {
  config.vim = {
    viAlias = true;   # provides a `vi`  symlink in the package's bin
    vimAlias = true;  # provides a `vim` symlink in the package's bin

    theme = {
      enable = true;
      name = "catppuccin";
      style = "mocha";
    };

    statusline.lualine.enable = true;
    telescope.enable = true;
    autocomplete.nvim-cmp.enable = true;

    # Per-language tooling (treesitter, LSP, formatters) in one switch:
    languages = {
      enableTreesitter = true;
      nix.enable = true;
      rust.enable = true;
    };

    lsp.enable = true;

    # Plain Neovim options and globals:
    options.shiftwidth = 2;
    globals.mapleader = " ";

    # Custom keymaps:
    keymaps = [
      {
        key = "<leader>e";
        mode = "n";
        action = ":Oil<CR>";
        desc = "Open file browser";
      }
    ];

    # Escape hatches when an option doesn't exist yet:
    extraPlugins = {
      # "<name>" = { package = pkgs.vimPlugins.<plugin>; setup = "require('x').setup{}"; };
    };
    luaConfigRC.myExtra = ''-- arbitrary Lua appended to init.lua'';
  };
}
```

Useful top-level categories under `vim`: `theme`, `statusline`, `lsp`,
`languages` (per-language LSP/treesitter/format), `autocomplete`, `telescope`,
`filetree`, `git`, `debugger`, `formatter`, `keymaps`, `options`, `globals`,
`extraPlugins`, `luaConfigRC`. The authoritative list is the
[options reference](https://nvf.notashelf.dev/options.html) — search it for the
exact path before inventing config.

## Consuming the built editor

`.neovim` is just a derivation, so install it like any other:

```nix
# NixOS / nix-darwin system module
environment.systemPackages = [neovim];

# home-manager
home.packages = [neovim];
```

With `viAlias`/`vimAlias` set, that also puts `vi`/`vim` on `PATH`. To make it the
default editor, set `EDITOR` (`environment.variables.EDITOR = "nvim";` or the
home-manager equivalent) — nvf does not own that.

## Fitting it into this dendritic repo

This repo is a flake-parts / dendritic config (see the **nix-config** skill). Two
clean ways to bring the standalone editor in:

1. **Separate flake input (most "its own flake").** Keep the Neovim flake above
   in its own repo (or subdir), add it to a feature's `flake-file.inputs`, then
   `nix run .#write-flake`. A program feature adds the package per class:

   ```nix
   # modules/programs/neovim/neovim.nix
   {inputs, ...}: let
     nvim = system: inputs.my-neovim.packages.${system}.default;
   in {
     flake.modules.darwin.neovim = {pkgs, ...}: {
       environment.systemPackages = [(nvim pkgs.system)];
     };
     flake.modules.nixos.neovim = {pkgs, ...}: {
       environment.systemPackages = [(nvim pkgs.system)];
     };
   }
   ```

2. **Build in-tree from the existing `nvf` input.** This repo already has `nvf` as
   a flake input, so a feature can call the builder directly and add the result to
   home-manager (home-manager-first is the repo default):

   ```nix
   # modules/programs/neovim/neovim.nix
   {inputs, ...}: {
     flake.modules.homeManager.neovim = {pkgs, ...}: {
       home.packages = [
         (inputs.nvf.lib.neovimConfiguration {
           inherit pkgs;
           modules = [./config.nix]; # config.vim = { … }
         }).neovim
       ];
     };
   }
   ```

   Then add `neovim` to a host/user's `imports`. Building from `pkgs` (the
   evaluating system's nixpkgs) keeps it cross-platform automatically.

Either way the editor config (`config.vim = { … }`) lives in a `config.nix`
beside the feature, so the same Neovim is reproduced on every machine.

## Migrating from the `programs.nvf` module

`configuration.nix` currently configures `programs.nvf.settings.vim = { … }`. The
option tree is identical — only the wrapper changes:

- `programs.nvf.settings.vim.<x>`  →  `config.vim.<x>` inside a `neovimConfiguration` module.
- `programs.nvf.enable = true;` has **no** equivalent — building the package *is*
  the enable.
- Everything under `settings.vim` (aliases, plugins, `languages`, `lsp`,
  `autocomplete`, `luaConfigRC`, etc.) copies across verbatim.

So migration is mostly: lift the `settings.vim` block into a `config.vim` module,
build it with the standalone builder, and add the resulting package where the
module used to be enabled.

## Validating

The package is a normal derivation — dry-build it, never `switch` (see `AGENTS.md`):

```sh
nix build .#neovim          # or .#default — builds the editor
nix run  .#                 # launch to smoke-test
nix flake check             # evaluate everything
nix run  .#write-flake      # only if you added/removed a flake input
```

Format Nix with **`alejandra`** (2-space indent), matching the rest of the repo.

## Reference

- nvf manual: <https://nvf.notashelf.dev/>
- Options reference (authoritative; search before inventing config):
  <https://nvf.notashelf.dev/options.html>
- nvf source: <https://github.com/NotAShelf/nvf>
- **nix-config** skill — how features/aspects/flake wiring work in this repo.
