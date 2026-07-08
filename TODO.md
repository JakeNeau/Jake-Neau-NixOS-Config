# TODO

- [ ] Remove the darwin manual workaround once nix-darwin#1819 is merged and
      flake inputs move past it: delete `modules/host-config/manual-workaround/`
      and its `manual-workaround` import line in
      `modules/host-config/roles/default/default.nix`.
- [ ] When next touching `CLAUDE.md`: the `nr`/`nrr` caution says
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
      exist; stylix home-manager config is delivered via the Linux hosts'
      `baselines` (`modules/nix/tools/stylix/stylix.nix`).
- [ ] Runtime theme switching:
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
      now satisfied: standalone home-manager is live. Known caveats to handle at
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
- [ ] Extend stylix theming to the macs. Verified: the pinned stylix input ships
      `darwinModules.stylix` and its home-manager module is platform-generic,
      so macOS support exists — the macs being unthemed today
      (`modules/nix/tools/stylix/stylix.nix` themes NixOS only; the macs theme
      nvf directly) is this repo's choice, not a stylix limitation. Scope:
      add `stylix` to the darwin hosts' `flake.hosts` `baselines` too, as the
      Linux hosts do (themes cross-platform apps like
      ghostty/kitty/neovim/bat/fzf), and
      evaluate the young/thin `darwinModules.stylix` for the system layer.
      Linux-only targets (GTK/Qt, cursor, wallpaper integration) won't apply
      on macOS. Deliberately kept out of the declaration-framework refactor to
      contain its scope. Relates to the runtime theme switching entry above.
- [ ] Build a custom Quickshell-based desktop shell for the niri hosts
      (redwood, spruce) — decided 2026-07-07 (after web research) to go all-in
      on hand-writing our own shell config on Quickshell rather than adopting a
      prebuilt shell or another framework. Two phases, now unblocked (the
      declaration-framework refactor has landed): write the spec
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
      `stylix.targets.noctalia-shell.enable`). The declaration-framework
      refactor (`docs/explanation/declaration-framework.md`) has landed — spec
      the shell against the framework it delivers (a program declaration /
      role entry); stylix home-manager config for standalone homes is routed
      via the Linux hosts' `baselines`
      (`modules/nix/tools/stylix/stylix.nix`).
- [ ] On the macOS hosts (aspen, cedar): swap Command and Option on
      built-in/Apple keyboards only, so Alt and Mod/Super sit in the same
      physical positions as on a standard PC keyboard. Must be scoped per
      device — an external Windows/PC keyboard plugged in keeps its default
      layout. Likely a per-device key remap via `hidutil` (or a nix-darwin
      keyboard option) restricted to Apple keyboard vendor/product IDs;
      probably lands in a darwin system module under `modules/host-config/`.
- [ ] Syncthing on every host plus the GrapheneOS phone; design settled
      2026-07-07. A `flake.programs.syncthing`
      declaration installs per-user via home-manager's `services.syncthing` on
      both platforms (verified cross-platform: systemd user service on Linux,
      launchd agent on macOS; only the tray is Linux-only), with folder paths
      built from `config.home.homeDirectory` so they work under both `/home/*`
      and `/Users/*`. Device mesh assembled by accumulation, dendritic-style:
      each host declaration contributes its own device ID via a field like
      `flake.hosts.<name>.syncthing.deviceId`, and a new small accumulated
      `flake.devices` option (attrsOf) holds non-Nix participants — the
      GrapheneOS phone's device ID lives there. The syncthing shared config
      maps over hosts ∪ devices to build `settings.devices`, so adding a host
      or device anywhere in the tree joins the mesh with no central list. Note:
      this must be flake-level accumulation, not `hostConstants` — the
      read-through delivers a home only its own host's facts, but every machine
      needs every device ID. Device IDs (decided 2026-07-07): pre-generate each
      host's TLS cert/key with `syncthing generate` and store them in sops
      (`secrets/secrets.yaml`), so every device ID is a permanent fact of the
      flake known ahead of first boot. Rationale: the impermanence and
      nixos-anywhere entries below mean hosts get wiped and reinstalled — a
      lost `/var/lib/syncthing` mints a new device ID and breaks the mesh,
      forcing re-pairing everywhere (including manually on the phone);
      pre-generated certs keep identity stable across reinstalls. The phone
      side is imperative by design:
      install Syncthing-Fork (the maintained F-Droid fork; the official Android
      app is abandoned), pair it once with redwood, and mark redwood as
      introducer so the phone auto-learns all other devices. redwood
      (always-on) is the de-facto hub; declare the full mesh in config anyway
      since syncthing connects opportunistically. Folders scoped per device
      (e.g. shared `~/sync` everywhere; camera roll phone→redwood only).
- [ ] Configure the NixOS hosts (redwood, spruce) with disko — declarative disk
      partitioning/formatting managed in the flake. Add the disko flake input,
      write a per-host disk layout matching each machine's current
      partitioning, and import it from the host declarations so
      `hardware-configuration.nix`-style filesystem config comes from the disko
      module. Done when both hosts' toplevels build with their disks declared
      via disko.
- [ ] Adopt impermanence (github.com/nix-community/impermanence) on the NixOS
      hosts (redwood, spruce): ephemeral root wiped on boot, with the paths
      that must survive explicitly persisted via the impermanence module.
      Consider pairing with the disko entry above (declarative disk layout) —
      an ephemeral-root setup is easiest to adopt at reinstall time, when the
      disk layout is being redone anyway.
- [ ] Reinstall the NixOS hosts (redwood, spruce) with nixos-anywhere —
      over SSH, from this flake, using the disko-declared disk layout. This is
      the tool that actually performs the reinstall the disko and impermanence
      entries above are waiting for: the three form the standard combo
      (nixos-anywhere wipes and partitions via disko, installs the flake's
      config, and impermanence keeps root ephemeral thereafter). Sequence it
      with those two entries.
- [ ] Remote deployment for the NixOS hosts: evaluate deploy-rs vs colmena,
      then wire one up so built configurations for redwood/spruce can be
      pushed from any machine instead of rebuilding on each host. Paired with
      a Linux builder or shared binary cache (tracked in the homelab section
      below), this also softens the "Darwin can't build NixOS hosts"
      limitation — build/verify once, deploy everywhere.
- [ ] Lanzaboote (Secure Boot) on the NixOS hosts (redwood, spruce). Natural
      to set up at the same reinstall moment as the
      disko/impermanence/nixos-anywhere combo above (bootloader and disk
      layout are being redone anyway) — sequence it with those entries.
- [ ] Tailscale mesh across every device — redwood, spruce, aspen, cedar, and
      the GrapheneOS phone; decided 2026-07-07. Tailscale (WireGuard
      underneath, hosted coordination server) won over plain WireGuard because
      the devices roam off-LAN regularly and need the NAT traversal and
      roaming that plain WireGuard's hub-and-spoke can't give — especially
      for the phone. Needs it serves: Syncthing sync (see the Syncthing entry
      above), SSH/remote admin — also what the remote-deployment entry above
      needs off-LAN — and reaching self-hosted services. The free Personal
      plan covers it (free forever, 6 users, unlimited devices). Declarative
      via `services.tailscale` on both NixOS and nix-darwin, pre-auth key in
      sops; the phone uses the official Android app (GrapheneOS-compatible).
      Prefer referring to hosts by MagicDNS name, never by tailnet IP, to keep
      the later Headscale migration cheap (IPs and the DNS suffix change on
      migration; bare hostnames survive). The Headscale entry in the homelab
      section below is the planned exit from the hosted coordination server.
- [ ] Declaration framework, boundary priority wrapper
      (`modules/nix/flake-parts/declarations/hosts.nix`, `wrapModule`): legacy
      `require` entries in shorthand modules pass through unwrapped, so their
      contents would land at priority 100 instead of the boundary's 900.
      `require` is deprecated and unused in this repo, so this is a fidelity
      gap only — either wrap it like `imports` or drop the note once `require`
      is gone from nixpkgs.
- [ ] Declaration framework, boundary priority wrapper
      (`modules/nix/flake-parts/declarations/hosts.nix`, `wrapModule`): a
      shorthand module's `freeformType` key gets priority-stamped instead of
      stripped the way nixpkgs `unifyModuleSyntax` strips it. Harmless today —
      it's the one inexact spot in the mirror — but strip it for exactness.
- [ ] Declaration framework, hosts generator guard
      (`modules/nix/flake-parts/declarations/hosts.nix`): a program declared
      with `handWritten = ["homeManager"]` but listed in a host's
      `globalPrograms` with a system install way makes the baseline reference
      a missing `homeManager."<name>-config"` aspect, failing with an
      unreadable "attribute missing" instead of the framework's readable
      throw. Add a readable declaration-eval throw before the stage-4/5
      conversions can hit it.
- [ ] Declaration framework, hosts/users generators
      (`modules/nix/flake-parts/declarations/hosts.nix` and `users.nix`):
      requesting the same program via both a host's `globalPrograms` and a
      user's `flake.users` entry on the same host double-imports the generated
      unit — for `hasEnableOption = false` programs that's a duplicate
      `programs.<name>.enable` option declaration error. Either dedupe user
      units against the host's `globalPrograms` at stamping, or add a readable
      throw.
- [ ] Declaration framework, users generator validation gap
      (`modules/nix/flake-parts/declarations/users.nix`): a `flake.users`
      declaration whose user is listed on no host is completely dead — none of
      its throws (including the unlisted-host check) ever fire, so it goes
      unvalidated. Add a validation pass that fires even for host-less users.
- [ ] Declaration framework, generated `-config` units
      (`modules/nix/flake-parts/declarations/programs.nix`): the enrichment
      that sets `programs.<name>.package = null` for programs declaring a true
      system install way assumes the program's home-manager module has a
      nullable `package` option (true for firefox and ghostty on the locked HM
      rev). Converting a future program with a system/cask way whose HM module
      lacks a nullable package will fail the -config unit's module type check —
      handle it then (suppress the class / hand-write, or extend the
      generator), and fold the assumption into the stage-7 generated-units
      reference documentation.
- [ ] Ghostty opacity on the NixOS hosts: the home-manager option
      `programs.ghostty.settings.background-opacity` merges two same-priority
      definitions — the ghostty unit's 0.9 and stylix's ghostty target's 1.0 —
      since HM's ghostty settings type turns repeated keys into lists. The
      stage-5 declaration-framework cutover flipped the merge order: pre-cutover
      the list was [0.9, 1.0], post-cutover [1.0, 0.9]. Ghostty gives repeated
      config keys last-wins semantics, so verify on a live Linux machine which
      occurrence ghostty actually honors after the cutover; if the wrong one
      wins, pin the intended 0.9 with `lib.mkForce` in
      `modules/programs/ghostty/ghostty.nix`.
- [ ] Yazi shell wrapper name (`modules/programs/yazi/yazi.nix`): decide
      between `yy` (legacy) and `y` (new default) and set
      `programs.yazi.shellWrapperName` in the yazi program declaration's
      config field. Since the stage-4 conversion enabled home-manager's
      `programs.yazi` per-user, every eval warns that the default changed
      from `yy` to `y` and the legacy default applies while
      `home.stateVersion` < 26.05. Setting either value silences the
      warning; the name is a user choice — no user was using either command
      before (yazi was system-installed without the HM wrapper).
- [ ] Decide whether the macs (aspen, cedar) should get yazi back: after the
      stage-5 declaration-framework cutover they no longer receive yazi's
      per-user install (pre-cutover it arrived via the role-default homeManager
      aggregate; the spec lists yazi only in the Linux hosts' `globalPrograms`).
      Spec-consistent, so this may be fine as-is — but if yazi is wanted on the
      macs, it's one `globalPrograms` entry in each mac's host declaration or a
      `flake.users` programs line.
- [ ] Declaration framework, stage 6: run `hr` once manually on the next
      deliberate rebuild to confirm end-to-end home activation. Stage 6 shipped
      the `hr` fish function and `nr`'s home-reactivation call
      (`modules/programs/fish/functions/`), validated only by `fish -n`,
      source-level proof of home-manager's flake-fragment quoting, and full
      flake builds — no actual `home-manager switch` was run. First-time note:
      `hr` itself is deployed by home activation, so the very first switch on a
      machine must be the full command:
      `home-manager switch -b backup --flake <repo>#<user>@<host>`. Migration
      bridge (verified 2026-07-08): after merging, the `nr`/`hr` on disk are
      still the pre-migration home generation's until a home activates once,
      so the first activation on each machine must be that full command; on
      cedar specifically the old `nr` aborts outright before rebuilding — its
      unquoted verify fragment fails on the new dotted
      `homeConfigurations."jake.neau@cedar"` output (proven by eval) — so run
      the manual home switch there BEFORE the first `nr`.

## When I get a homelab

- [ ] Shared binary cache / remote builder: e.g. harmonia or attic serving
      from an always-on homelab machine, or nix-darwin's `linux-builder` on
      the macs, so the macs can build and verify NixOS toplevels and all
      hosts share build results instead of rebuilding independently.
      Complements the remote-deployment entry in the main list above.
- [ ] Declarative backups (restic or borgbackup) — no backups are declared
      anywhere in this repo today. NixOS has `services.restic.backups`;
      home-manager can cover the macs. Strong synergy with the impermanence
      entry above: the explicit persist list impermanence forces is exactly
      the backup manifest. A homelab machine is the natural backup target.
- [ ] Headscale — self-hosted open-source reimplementation of Tailscale's
      coordination server. If the Tailscale entry in the main list above is
      already implemented by then, migrate: point every client at the
      self-hosted server (`--login-server`, one line in the shared module,
      plus new pre-auth keys; devices get new tailnet IPs and a new MagicDNS
      suffix, and ACLs port with minor fixes). If Tailscale was not
      implemented yet, skip the hosted service entirely and implement
      Headscale directly. Either way the clients are the ordinary Tailscale
      apps. Needs a stable publicly-reachable address (the homelab box with a
      port forward, or a small VPS); NixOS has a `services.headscale` module.
      Rationale: removes the third-party coordination dependency — runtime
      traffic is end-to-end WireGuard either way.
