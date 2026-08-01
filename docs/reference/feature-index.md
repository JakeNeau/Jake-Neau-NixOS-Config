# Feature index

One line per directory: every directory under `modules/`, plus the
non-module top-level directories. What a directory *is* (feature module,
host, role, ...) follows from its place in the tree; how the pieces
compose: [the flake machinery](../explanation/flake-machinery.md).

## Top level

- `docs/` — this documentation tree, organized by Diátaxis quadrant.
- `secrets/` — sops-encrypted secrets (`secrets.yaml`); the age key
  (`keys.txt`) is never committed. Flow: [Add a
  secret](../how-to/declarations/add-a-secret.md), [secrets](../explanation/secrets.md).
- `specs/` — transient pre-implementation design docs: write → implement →
  document → delete.
- `wallpapers/` — wallpaper images referenced by stylix and hosts.
- `modules/` — every `.nix` below is auto-imported as a flake-parts
  module.

## modules/config

- `hidden-desktop-entries/` — hides launcher entries for tools that ship a
  `.desktop` file but shouldn't appear (Qt shims, bare terminals, the
  NixOS manual).

## modules/factory

- `user/` — `flake.factory.user`: stamps a user's account aspects and home
  aspect from `(username, isAdmin)`. See [generated user
  artifacts](generated-user-artifacts.md).

## modules/host-config

Machine-level config: what needs root, shared by all users.

- `audio/` — the NixOS sound stack: pipewire (alsa/pulse/jack bridges) and
  rtkit, plus the GUI tools to operate it.
- `caps-dual-role/` — caps lock as ctrl-when-held / escape-when-tapped on
  both platforms (kanata on NixOS, Karabiner on macOS).
- `cli/` — cross-platform command-line programs shared by NixOS desktops
  and macOS hosts.
- `config-group/` — the `config` group that grants members write to this
  repo without sudo. See [config-group](../explanation/config-group.md).
- `copy-paste-remaps/` — Linux-style ctrl+c/ctrl+v everywhere, GUI and
  terminal, both platforms.
- `graphics/` — GPU enablement plus per-vendor modules (amd, intel,
  nvidia, apple) that self-activate on `hostConstants.graphicsType`. See
  [graphics self-activation](../explanation/graphics-self-activation.md).
- `host-constants/` — the `hostConstants` option schema: declared facts
  about a host that features branch on. See [host
  facts](../explanation/host-facts.md).
- `key-repeat/` — key-repeat timing declared once, shared across
  platforms.
- `monitor-power/` — coordinates Niri DPMS with pluggable firmware backends.
  It controls monitors through DDC/CI by default. It also provides the generic
  Samsung Tizen factory that Redwood configures. See [monitor power
  control](../explanation/monitor-power.md).
- `network/` — hostname wiring from `hostConstants.hostName` on both
  platforms.
- `printing/` — CUPS with avahi/mDNS discovery on NixOS; print-dialog
  defaults on macOS.
- `roles/` — layered baselines naming what a host *is*:
  - `minimal/` — `role-minimal`: baseline settings every system and home
    needs (nix daemon settings, `home.stateVersion`, ...).
  - `default/` — `role-default`: minimal plus the tooling used everywhere
    (secrets-management, config-group, git, direnv, printing, ...).
  - `desktop/` — `role-desktop`: the coarse desktop layer shared by every
    workstation.
  - `niri-desktop/` — the complete niri wayland desktop in one import
    (compositor, portals, greetd session, per-user wayland plumbing);
    NixOS-only.

## modules/hosts

Each holds the host's `flake.hosts` declaration plus its hand-written
quirks aspect.

- `aspen/` — Jake's personal MacBook (darwin).
- `cedar/` — the macOS work laptop (darwin).
- `redwood/` — the NixOS desktop, its generated hardware config,
  [deep-only S3 suspend policy](../explanation/redwood-suspend.md), Minecraft
  server definitions, and Samsung Odyssey monitor power backend.
- `spruce/` — the NixOS laptop (placeholder hardware config until the
  machine exists).

## modules/nix

Flake-level machinery and third-party tool wiring.

- `flake-parts/` — the flake-parts substrate: `dendritic-tools.nix`
  (flake-parts + flake-file + import-tree), `factory.nix` (the
  `flake.factory` option), `darwinConfigurations-fix.nix` (declares the
  `flake.darwinConfigurations` option nix-darwin doesn't).
  - `declarations/` — the three generators: `programs.nix`, `hosts.nix`
    (including the boundary priority wrapper), `users.nix`.
- `tools/` — one folder per external Nix tool:
  - `home-manager/` — the home-manager flake input and
    `flake.homeConfigurations` option, plus the
    [common nixpkgs module](common-nixpkgs.md).
  - `mac-app-util/` — real trampoline apps so LaunchServices sees
    Nix-installed macOS apps.
  - `minegrub/` — Minecraft-themed GRUB.
  - `nix-darwin/` — the nix-darwin input: declarative macOS system config.
  - `nix-homebrew/` — declarative Homebrew installation management.
  - `nix-minecraft/` — declarative Minecraft servers; importing it means
    "this host runs a minecraft server".
  - `nixpkgs/` — the package set everything builds from.
  - `nur/` — the Nix User Repository overlay (community packages, e.g.
    browser addons).
  - `stylix/` — system-wide theming. See [stylix
    theming](../explanation/stylix-theming.md).

## modules/programs

One folder per program feature; converted ones carry a `flake.programs`
declaration, the rest are hand-written aspects.

- `beekeeper-studio/` — cross-platform SQL client.
- `blender/` — 3D modeling/art, with HIP GPU rendering on AMD hosts.
- `candy-icons/` — gradient vector icon theme.
- `claude-code/` — Anthropic's terminal coding assistant, declaratively
  configured; `jake.neau`'s agent. Its `config/skills/` carries every skill it
  loads, including its writing, comment, and documentation policies, and
  `writing-lint.nix` packages the `claude-writing-lint` binary from `writing/`.
  See [claude-code config](../explanation/claude-code-config.md), [Claude Code's
  writing system](../explanation/claude-code-writing-system.md), [coding
  agents](../explanation/coding-agents.md), [the /pr-review-guide
  command](../explanation/pr-review-guide-command.md).
- `cli-tools/` — cross-platform command-line tools via home-manager.
- `clipse/` — clipboard manager with a TUI history picker.
- `davinci-resolve/` — professional video editor, with Rusticl OpenCL on
  AMD hosts.
- `direnv/` — per-project environments with nix-direnv caching.
- `fastfetch/` — system-info splash, branched on `hostConstants` facts.
- `firefox/` — the multi-way declaration: home-manager install by default,
  macOS cask via `installOverrides` where the nix package breaks.
- `fish/` — the default interactive shell, plus the autoloaded functions
  (`nr`, `hr`, `mc-*`, ...).
- `fuzzel/` — wayland application launcher.
- `ghostty/` — GPU-accelerated terminal; Linux home install, macOS cask
  with home-manager config.
- `git/` — git identity at both the per-user and system level. The home-manager
  half also allowlists this repo's paths in `safe.directory`, scopes
  `core.sharedRepository = "group"` to it via `gitdir:` includes, and warns at
  activation about an unmanaged `~/.gitconfig`.
- `homebrew/` — the Homebrew cask list for packages that work better
  outside nixpkgs.
- `hyprlock/` — styled screen locker for niri sessions.
- `jujutsu/` — jj, a git-compatible VCS, configured through home-manager.
- `karabiner/` — the macOS key-remapping daemon (app from homebrew).
- `kubernetes/` — install-only declaration: kubectl + k9s behind a
  generated enable toggle.
- `libreoffice/` — office suite.
- `librewolf/` — privacy-hardened Firefox fork, Jake's daily browser.
- `nvf/` — declarative Neovim, the same editor on every host.
- `papirus-icon-theme/` — fallback icon set.
- `pavucontrol/` — sound settings GUI.
- `pi/` — `jakeneau`'s coding agent, with declarative web research and native
  browser extensions, the matching browser CLI, and the numtide binary-cache
  aspect. Its `config/skills/` carries every skill it indexes, including its
  writing, comment, and documentation policies, and `writing/` holds the
  `pi-writing-lint` source. See [pi](pi.md), [Pi's writing
  system](../explanation/pi-writing-system.md), [coding
  agents](../explanation/coding-agents.md).
- `podman/` — daemonless container engine.
- `qpwgraph/` — pipewire patchbay.
- `secrets-management/` — sops-nix + age: the `sops`/`age` CLIs per user on
  both platforms, plus the hand-written `nixos` aspect that decrypts
  `secrets/secrets.yaml` at activation. See [Add a
  secret](../how-to/declarations/add-a-secret.md),
  [secrets](../explanation/secrets.md).
- `sioyek/` — keyboard-driven PDF reader.
- `spotify/` — Spotify, wrapped to launch with `--in-process-gpu`.
- `swaybg/` — wayland wallpaper setter.
- `udiskie/` — automatic removable-media mounting.
- `ungoogled-chromium/` — Chromium with Google integration removed.
- `wl-clip-persist/` — keeps clipboard contents alive after the source
  window closes.
- `wl-clipboard/` — command-line copy/paste for wayland.
- `xwayland-satellite/` — rootless Xwayland for niri.
- `yazi/` — TUI file browser; on Linux also the xdg-desktop-portal file
  chooser (hand-written `nixos` aspect).

## modules/users

Each holds the user's `flake.users` declaration (where one exists), the
factory instantiation, and per-user config.

- `jake.neau/` — Jake's work user; cedar only; claude-code and
  secrets-management via `programs`, kubernetes via `hosts.cedar.programs`.
- `jakeneau/` — Jake's personal user; the NixOS machines and the personal
  MacBook; pi and secrets-management via `programs`.
