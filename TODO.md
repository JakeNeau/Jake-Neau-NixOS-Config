# TODO

- [ ] Remove the darwin manual workaround once nix-darwin#1819 is merged and
      flake inputs move past it: delete `modules/system/manual-workaround/` and
      its `manual-workaround` import line in
      `modules/system/types/system-default/system-default.nix`.
- [ ] When next touching `CLAUDE.md` (lines 70-72): the `nr`/`nrr` caution says
      the flow unconditionally runs `git add -A`, which under-describes the new
      `nr -s`/`--staged` flag (stages only `flake.lock` and stashes unstaged
      tracked changes; see `modules/programs/fish/functions/nr.fish`). Update
      the sentence to cover both modes. Low priority.
- [ ] Update the specs conventions so new specs never cite code by line number —
      cite file paths with durable content anchors (symbol names or short quoted
      phrases) instead, since line numbers rot as the tree changes under a spec's
      multi-stage implementation. Land it in the specs-writing guidance:
      `modules/programs/claude-code/config/skills/specs/SKILL.md` and/or
      `modules/programs/claude-code/config/agents/spec-writer.md`. Context:
      `specs/declaration-framework.md` had ~98 `file:line` citations, several of
      which drifted within a few generations; replaced with content anchors on
      2026-07-06.
- [ ] Restructure librewolf into four profiles in
      `modules/programs/librewolf/librewolf.nix` (currently a single `default`
      profile): `work` (relaxed hardening), `strict` (strict hardening — today's
      `default` becomes this), `compatibility` (relaxed hardening), and
      `development` (no extensions, no hardening). Apply Stylix theming to every
      profile except `development` by setting
      `stylix.targets.librewolf.profileNames` to work/strict/compatibility —
      Linux only, since the macs have no stylix. Stylix doesn't theme librewolf
      at all today, so the theming wiring only matters once these profiles
      exist; coordinate with where the declaration-framework spec routes stylix
      home-manager config.
- [ ] Runtime theme switching (after the declaration-framework refactor lands):
      keep stylix and add one home-manager specialisation per color scheme —
      the base theme stays gruvbox-material-dark-hard via `lib.mkDefault`, and
      each variant overrides `stylix.base16Scheme` / `stylix.image` /
      `polarity` with `lib.mkForce`. All variants prebuild in one
      `home-manager switch`; a niri keybinding then switches theme in seconds
      without a rebuild by running the prebuilt
      `<generation>/specialisation/<name>/activate` script, wrapped in
      `niri msg action do-screen-transition --delay-ms 600` so the whole
      desktop crossfades at once. The wallpaper gets a true diagonal wipe via
      awww (the maintained successor of swww; works on niri):
      `awww img <wallpaper> --transition-type wipe --transition-angle 30` in
      each variant's activation. Depends on standalone home-manager —
      specialisation activation is then a plain user-level command, no sudo —
      which is why it waits for the refactor. Known caveats to handle at
      implementation time: GTK/Qt apps don't live-reload a full scheme swap
      (restart needed; new windows are correct; the crossfade masks it), fish
      needs the universal-variable re-source trick (pltanton's write-up:
      https://pltanton.dev/posts/nix-based-dark-light-theme-switch/), old home
      generations must be kept from GC while a specialisation is active, and
      HM `specialisation` is flagged experimental. Watch niri PR #3531 (custom
      GLSL screen-transition shaders, open as of May 2026) — once merged, the
      crossfade upgrades to a true diagonal wipe over the apps. Context
      sources: stylix issue #447 (maintainers endorse the specialisation
      pattern and plan to absorb it), stylix issue #1863, and vlaci's
      stylix+niri+darkman write-up
      (https://vlaci.github.io/nix.org/posts/theming).
- [ ] Extend stylix theming to the macs (after the declaration-framework
      refactor lands). Verified: the pinned stylix input ships
      `darwinModules.stylix` and its home-manager module is platform-generic,
      so macOS support exists — the macs being unthemed today
      (`modules/nix/tools/stylix/stylix.nix` themes NixOS only; the macs theme
      nvf directly) is this repo's choice, not a stylix limitation. Scope:
      import the stylix home-manager module into the darwin hosts' baselines
      too (themes cross-platform apps like ghostty/kitty/neovim/bat/fzf), and
      evaluate the young/thin `darwinModules.stylix` for the system layer.
      Linux-only targets (GTK/Qt, cursor, wallpaper integration) won't apply
      on macOS. Deliberately kept out of the declaration-framework refactor to
      contain its scope. Relates to the runtime theme switching entry above.
- [ ] Build a custom Quickshell-based desktop shell for the niri hosts
      (redwood, spruce), after the declaration-framework refactor lands —
      decided 2026-07-07 (after web research) to go all-in on hand-writing our
      own shell config on Quickshell rather than adopting a prebuilt shell or
      another framework. Two phases, both after the refactor: write the spec
      (brainstorm → `specs/` file per the specs skill) covering the component
      suite (bar, notification center/daemon, launcher, OSDs, lock/idle) and
      the module shape; then implement as a feature under `modules/programs/`
      (or wherever the spec routes it). Framework rationale: Quickshell won
      over AGS/Astal (no merged niri library, no HM module, no stylix path),
      eww (semi-stagnant, last release 2024), fabric (pre-1.0), and ironbar
      (bar-only, though active with native niri support); the niri community's
      complete shells (Noctalia ~8.4k stars, DankMaterialShell ~7.2k) are all
      Quickshell-based — use them as reference codebases while writing our own
      QML. Nix story: quickshell is in nixpkgs, and the QML tree is
      home-manager-symlinked files, fully declarative. Theming: stylix won't
      auto-theme a custom shell — template `config.lib.stylix.colors` (base16
      palette) into a QML colors module so the shell follows the scheme and
      the planned specialisation-based runtime theme switching (see the
      "Runtime theme switching" entry above — related); live-reload on config
      swap is unverified, so plan for the specialisation activation script to
      restart the shell's systemd user unit. Theme niri itself via sodiboo's
      niri-flake `stylix.targets.niri` (upstream stylix has no niri target).
      Fallback if the custom build stalls: Noctalia was the researched winner
      among prebuilt shells (flake + HM module + upstream
      `stylix.targets.noctalia-shell.enable`). Sequencing is decided: both
      phases start only after the declaration-framework refactor
      (`specs/declaration-framework.md`) lands — spec the shell against the
      framework it delivers (a program declaration / role entry) and implement
      then; it also depends on how that refactor routes stylix home-manager
      config for standalone homes (tracked in that spec).
- [ ] On the macOS hosts (aspen, cedar): swap Command and Option on
      built-in/Apple keyboards only, so Alt and Mod/Super sit in the same
      physical positions as on a standard PC keyboard. Must be scoped per
      device — an external Windows/PC keyboard plugged in keeps its default
      layout. Likely a per-device key remap via `hidutil` (or a nix-darwin
      keyboard option) restricted to Apple keyboard vendor/product IDs;
      probably lands in a darwin system module under `modules/system/`.
