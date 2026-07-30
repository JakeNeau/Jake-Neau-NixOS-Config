# Stylix theming

How system-wide theming works after the standalone-homes restructure, and
why macOS is deliberately out of scope
(`modules/nix/tools/stylix/stylix.nix`).

## One theme function, two aspects

Stylix themes the NixOS system layer and each standalone home. These module
systems no longer share an evaluation. Separate theme declarations could drift.

A `let`-bound `theme` function holds the scheme, polarity, wallpaper, cursor,
and fonts. The function accepts `pkgs` because the cursor and fonts reference
packages. Both aspects use this function:

- `flake.modules.nixos.stylix` imports Stylix's NixOS module and themes the
  system layer.
- `flake.modules.homeManager.stylix` imports Stylix's Home Manager module and
  themes standalone homes.

Both aspects therefore state the same theme.

## Linux-only delivery

Only the Linux host baselines include the Home Manager aspect. Before
standalone homes, Stylix's NixOS module imported its Home Manager module
through the Home Manager system module. Removing that system module also
removed the implicit delivery. The explicit baseline delivery replaces it.

Baselines pass through the boundary priority wrapper. Stylix's settings
therefore use priority 900 in each home. A user can override them with a plain
assignment.

The NixOS aspect disables Stylix's ReGreet target because both Linux hosts
launch Niri directly through greetd and do not use ReGreet. Otherwise, Stylix
populates inactive display-manager settings.

The home-manager aspect disables Stylix's Hyprland target because both Linux
hosts use Niri. Otherwise, Stylix populates dead Hyprland settings and triggers
Home Manager's Hyprland state-version warning.

## macOS: deliberately out of scope

The current Stylix input contains `darwinModules.stylix`. Its Home Manager
module also supports macOS. This repo deliberately does not connect either
module on macOS.

The Macs theme nvf directly through `modules/programs/nvf`. `TODO.md` tracks
macOS theming and runtime theme switching as future work. The Linux-only design
is a scope decision, not a technical limitation.
