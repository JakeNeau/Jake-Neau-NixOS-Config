# TODO

- [ ] On cedar, verify the built-in display resolution and correct
      `hostConstants.displayResolution` if it differs from the temporary
      2560x1664 value copied from aspen.
- [ ] After activating the LibreWolf profile configuration, complete this live
      verification:
      1. Confirm that `work` retains cookies and site storage without
         exceptions.
      2. Remove all persistence exceptions from `strict` and `development`,
         and add any required exceptions to `compatibility`.
      3. Check all four Linux menu entries, names, and icons.
      4. Inspect Linux icons at 16, 24, 32, 48, 64, and 128 pixels.
      5. Check all four macOS Spotlight and Launchpad entries, names, and icons.
      6. Inspect macOS icons at 16, 32, 48, 64, and 128 pixels.
      7. Verify that each command and graphical launcher opens its named profile.
      8. With `work` running, invoke `librewolf-work` with a test URL.
      9. With only `strict` running, invoke `librewolf-work` with a test URL.
      10. Launch the same nondefault profile twice.
      11. Run all four profiles concurrently.
      12. Confirm repeated launches and URLs avoid profile-lock and routing
          failures.
      13. Close each profile normally and reopen it.
      14. Confirm that `strict` and `development` retain no cookies or site
          storage.
      15. Confirm that `work` retains all site data and `compatibility` retains
          data only for its exception list.
      16. Confirm that `work` and `compatibility` do not share retained data.
      17. Confirm that each extension list matches the LibreWolf reference.
      18. Confirm that `development` has no Stylix browser theme.
      Complete this item only after persistence setup, repeated-launch tests,
      URL-routing tests, and profile-isolation checks pass.
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
- [ ] Share LSP (Language Server Protocol) server config between Neovim (via
      nvf) and Claude Code instead of declaring each server twice:
      `modules/programs/nvf/nvf.nix` declares LSP servers for Neovim, and
      `modules/programs/claude-code/claude-code.nix` has its own separate
      `lspServers` attrset for Claude Code — the two lists overlap heavily
      (same language, same command/args/package) but are maintained
      independently. Factor the common per-language server config (command,
      args, package, etc.) into one shared declaration that both modules read
      from, so adding or updating a language server is a one-place edit
      instead of two.
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
- [ ] Declaration framework, boundary priority wrapper
      (`modules/nix/flake-parts/declarations/hosts.nix`, `wrapValue`):
      accumulative *string* options (`types.lines`, extraConfig-style) are
      still demoted to priority 900 by the wrapper. The Nix module system's
      priority filtering keeps only the winning priority's definitions, so a
      shared lines contribution is silently dropped whenever any
      plain-priority (100) definition of the same option exists — the same
      delete-not-demote hazard just fixed for lists by exempting them from
      stamping. Strings can't get the same exemption: at the value level a
      `types.lines` string is indistinguishable from a plain scalar string
      (where 900-stamping is correct and wanted), so fixing this needs a
      different approach (e.g. option-type awareness, or per-option
      carve-outs with explicit `lib.mkOverride 100` markers as
      `nixpkgs.config` still uses).
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
- [ ] Decide whether the macs (aspen, cedar) should get yazi back: after the
      stage-5 declaration-framework cutover they no longer receive yazi's
      per-user install (pre-cutover it arrived via the role-default homeManager
      aggregate; the spec lists yazi only in the Linux hosts' `globalPrograms`).
      Spec-consistent, so this may be fine as-is — but if yazi is wanted on the
      macs, it's one `globalPrograms` entry in each mac's host declaration or a
      `flake.users` programs line.
- [ ] Clean superpowers out of live Claude Code state on cedar: `claude
      plugin uninstall superpowers@claude-plugins-official` to clear the
      cache, then jq-delete the
      `enabledPlugins."superpowers@claude-plugins-official"` key from
      `~/.claude/settings.json`. Removing the key from `settingsPolicy`
      in `modules/programs/claude-code/claude-code.nix` is not enough — the
      activation merge (`. * $policy`) is additive and preserves keys absent
      from the policy.
- [ ] Remove the imperative Claude Code install from redwood entirely:
      uninstall the package however it was installed (likely npm or the
      native installer) and delete the `~/.claude` and `~/.claude.json`
      state. Redwood's declared harness is pi; the Claude Code install
      was a scratch install that predates the superpowers removal.
- [ ] Add an MCP adapter to Pi's typed-link registry for `[[mcp:<name>]]`
      links. It must discover configured Model Context
      Protocol servers, resolve each link to useful metadata, and invoke the
      server through whichever reviewed Pi MCP extension is adopted. Until
      then, MCP links must resolve as explicitly unsupported rather than fail
      silently.
- [ ] Extend the shared typed-link vocabulary with `[[extension:<name>]]` and
      add a Pi adapter that resolves installed
      extensions to their metadata and source. Update the extension-authoring
      guidance so every new Pi extension considers whether it introduces a
      reusable resource kind that needs its own typed link and adapter.
- [ ] Backfill a committed regression test for the `edit-briefing` PreToolUse
      hook (`modules/programs/claude-code/config/hooks/edit-briefing`) once a
      bash test harness for this repo's Claude Code hooks exists — none does
      today (no existing hook is tested), and the hook was verified only by 11
      ad-hoc synthetic-stdin checks during implementation. The test must cover:
      emits `permissionDecision:"ask"` for a default-mode subagent Edit/Write;
      stays silent (exit 0) on `acceptEdits`/`bypassPermissions`/`plan` and for
      main-session edits (no `agent_type`); surfaces the WHY from the ledger and
      consumes it FIFO; prunes ledger lines older than 12h; and is fail-open
      (exit 0, no output) on malformed/empty stdin.
- [ ] Interactive post-rebuild render check for the edit-briefings feature
      (user-owned, per Task 6 of `specs/edit-briefings.md`). After the next
      system rebuild, confirm the four-part briefing renders immediately above
      the Edit/Write accept-deny prompt via `permissionDecision:"ask"` +
      `permissionDecisionReason`. If it double-prompts or misbehaves where Edit
      is allow-listed, switch the hook's final jq output to a `systemMessage`
      payload (the documented fallback in `specs/edit-briefings.md`) and
      rebuild. The hook lives at
      `modules/programs/claude-code/config/hooks/edit-briefing`. The spec
      `specs/edit-briefings.md` is intentionally kept (not retired) until this
      check passes.
- [ ] Decide whether to rewrite `modules/programs/claude-code/config/CLAUDE.md`
      to obey its own form policy. Its `## 3. How you write` section requires no
      em dashes, no semicolons, no contractions, one claim per sentence, and a
      25-word sentence limit — but sections 1-2 and 4-12 are full of em dashes,
      semicolons, contractions, and much longer sentences. The prose predates
      section 3; section 3 is what made the file self-inconsistent. User's call
      whether to rewrite those sections or narrow the policy.
- [ ] Split the multi-claim `test()` block in
      `modules/programs/pi/extensions/typed-links/tests/writing-resources.test.mjs`
      into one `test()` per claim, so the first failure stops masking the rest.
      Context: a tautological assertion (`link.targetId?.startsWith("global:")`,
      which can never fail because `compileGlobalRegistry` hardcodes
      `layer: "global"`) was removed from that file on 2026-07-28; the packing
      problem it sat in remains.
- [ ] Consider neutralizing the cross-agent mentions in the two user
      declarations' explanatory comments: `modules/users/jakeneau/jakeneau.nix`
      lines 10-11 and `modules/users/jake.neau/jake.neau.nix` lines 8-10 each
      name both coding agents, though the `programs` lists themselves name only
      that user's own agent. These files sit outside both agents' trees, so the
      agent-config split left them alone — reword only if consistency with the
      agent-isolation rule is wanted there too. Low priority.
- [ ] Guard the dangling stop-waiter in `CodeLldbSession.resume()` in
      `modules/programs/pi/extensions/rust-tools/dap.ts` — it has the same defect
      already fixed in `launch()`: it creates `const stopped =
      this.waitForStop();` and then awaits `this.connection.request(command,
      args)`. If that request rejects, no event ever settles `stopped`, so
      `close()` later rejects it with "debug session closed" and it surfaces as
      an unhandled rejection — which under Node's default
      `--unhandled-rejections=throw` can be blamed on an unrelated test or kill
      a live Pi session. Apply the same one-line `stopped.catch(() => {});`
      immediately after `waitForStop()` that `launch()` now uses. Done means a
      failing resume request produces only the wrapped `${label} failed: ...`
      error, with no unhandled rejection when the session closes. Deferred from
      the pi-rust-tools aarch64-darwin check fix, whose scope was three tests
      plus the minimum production change.
- [ ] Give the one direct `RustAnalyzerSession.start` call in
      `modules/programs/pi/extensions/rust-tools/tests/lsp.test.ts` (the
      "synchronizes source changes after a document is opened" test) an explicit
      `readyTimeoutMs`. It still passes only `timeoutMs: 500`, so the startup
      handshake and every subsequent request share a single 500ms budget. The
      shared `start()` helper in the same file already passes an explicit
      generous `readyTimeoutMs: 30_000` — the option added to
      `RustAnalyzerStartOptions` in `lsp.ts`, which defaults to `timeoutMs` so
      existing callers are unchanged. Done means this call cannot become
      load-flaky the way the "times out unanswered language-server requests"
      test did (it failed roughly 1 run in 5 with `initialize request timed out
      after 30ms`). Low priority.
- [ ] Check whether the `/etc/nix-darwin` entry in `settings.safe.directory`
      (`modules/programs/git/git.nix`) is redundant, and remove it if so.
      `/private/etc/nix-darwin` is the repository's resolved real path, which
      satisfies libgit2 and the git CLI alike. So the unresolved spelling may
      carry no weight, while `/etc/nixos` stays either way as the real path on
      Linux. The 2026-07-28 comment-only pass over that file deliberately left
      this out, since dropping an allowlist entry is a behavior change needing
      its own verification. Confirm with
      `nix flake metadata /private/etc/nix-darwin`, not with `git status`,
      because only a libgit2 consumer proves the allowlist does the work.
- [ ] Verify and fix the NixOS side of `core.sharedRepository`: the
      `gitdir:/etc/nixos/` include does NOT reach root-run git on NixOS. Proven
      on redwood — its generated sudoers
      (`/nix/store/2s8b1ql4qw5k4wc9fj83yg2xagxdw9vw-sudoers`) has no
      `env_keep HOME`, so the `sudo git -C /etc/nixos` calls in
      `modules/programs/fish/functions/nr.fish` read root's gitconfig, not the
      user's home-manager one. macOS escapes this only because Apple's
      `/etc/sudoers` carries `env_keep += "HOME MAIL"`. If NixOS hosts show the
      same `.git` permission decay, the fix needs a different mechanism — set
      `core.sharedRepository` in root's own gitconfig, or add a system-level
      `/etc/gitconfig` `includeIf` in `flake.modules.nixos.git`. Unverified on a
      real Linux host (no Linux builder on the macs).
- [ ] Delete the stopgap `/Users/jake.neau/.gitconfig` once the next rebuild has
      activated the managed git config, leaving home-manager the single source of
      truth. Whether to fold it in is settled: its `user.name`/`user.email` were
      redundant and are gone, and its one remaining line,
      `[safe] directory = /private/etc/nix-darwin`, is now declared in
      `modules/programs/git/git.nix`. The file survives only until that managed
      entry is live, because `nix` needs the allowlist to read the flake at all.
      Verify the removal with `nix flake metadata /private/etc/nix-darwin`, not
      with `git status` — the CLI succeeds either way, so only a libgit2 consumer
      proves the managed entry is doing the work. Home activation warns about the
      file on every `hr` until it is gone, and anything left in it silently
      overrides `~/.config/git/config`.
- [ ] Extend sops secret consumption to the macs (aspen, cedar). Today only the
      NixOS side decrypts secrets: the hand-written
      `flake.modules.nixos.secrets-management` aspect has no darwin equivalent,
      and the `secrets-management` program's `install.macos`
      (`modules/programs/secrets-management/secrets-management.nix`) covers only
      the `sops`/`age` CLIs, not any decryption wiring. Done means a darwin
      counterpart decrypts secrets on the macs the way the NixOS aspect does.
      Deliberately deferred when the program was created.
- [ ] Decide whether `secrets-management` should be a host `globalPrograms`
      entry rather than a per-user `flake.users.<u>.programs` entry. It is
      currently declared by both users individually
      (`modules/users/jakeneau/jakeneau.nix`,
      `modules/users/jake.neau/jake.neau.nix`). Going global per host would give
      any new user the `sops`/`age` CLIs automatically and remove three
      documentation caveats that must otherwise be stated by hand: that the CLIs
      reach only users who declare the program, that they arrive at home
      activation rather than at the system switch, and that a new user who edits
      secrets must add the program. A design question for the user to decide,
      not a defect.

## Waiting on upstream

- [ ] Remove the `agents-md-context` session-start hook once Claude Code
      natively supports BOTH conventions it bridges: reading a project-root
      `AGENTS.md` (upstream feature request: anthropics/claude-code#6235) AND
      auto-discovering skills in the cross-tool `.agents/skills/` directory
      (upstream feature request: anthropics/claude-code#22902). Both must land
      first — until then the hook still does at least one useful job. When they
      do, delete the hook script
      `modules/programs/claude-code/config/hooks/agents-md-context` and its
      `settingsPolicy.hooks.SessionStart` registration in
      `modules/programs/claude-code/claude-code.nix`.
- [ ] Report the fishPlugins.pure build failure upstream to nixpkgs — pure
      4.15.0's fishtape test suite fails 24/286 tests in the Nix build sandbox
      (permission-denied errors, likely caused by Nix >= 2.30 moving build
      dirs from /tmp to /nix/var/nix/builds; same failure class as nixpkgs
      issues #510488 (nushell) and PR #535763 (mise)). The failure appears
      unreported for pure. Once fixed upstream (or checks are dropped from
      fish plugin packaging per the maintainer stance in nixpkgs PR #393174),
      remove the `doCheck = false` override on pure in
      `modules/programs/fish/fish.nix`.

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
