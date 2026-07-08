# Stylix theming

How system-wide theming works after the standalone-homes restructure, and
why macOS is deliberately out of scope
(`modules/nix/tools/stylix/stylix.nix`).

## One theme function, two aspects

Stylix themes two module systems that no longer share an eval: the NixOS
system layer and each standalone home. If the theme were stated in one
aspect and imported by the other, the layers could drift; if stated twice,
they *would* drift. So the theme values — scheme, polarity, wallpaper,
cursor, fonts — live in one `let`-bound function at the top of the file, a
function of `pkgs` because the cursor and fonts reference packages, and
are spliced into both aspects:

- `flake.modules.nixos.stylix` — imports stylix's NixOS module; themes the
  system layer (console, greeter, boot-adjacent surfaces).
- `flake.modules.homeManager.stylix` — imports stylix's home-manager
  module; themes standalone homes.

Both state the identical theme by construction.

## Linux-only delivery

The home-manager aspect rides the Linux hosts' baselines only. Before
standalone homes, per-user theming arrived implicitly — stylix's NixOS
module auto-imported its home-manager module through the home-manager
system module; that path died with the system module, so the explicit
baseline delivery replaces it.

Because baselines pass through the boundary priority wrapper, stylix's
settings land at priority 900 in each home — a user can restyle any of it
by plain assignment.

## macOS: deliberately out of scope

macOS theming was verified *possible* — the pinned stylix ships
`darwinModules.stylix`, and its home-manager module is platform-generic —
but is deliberately not wired: the macs theme nvf directly (see
`modules/programs/nvf`), and both macOS theming and runtime theme
switching are tracked in `TODO.md` as future work. The Linux-only shape is
a scope decision, not a limitation.
