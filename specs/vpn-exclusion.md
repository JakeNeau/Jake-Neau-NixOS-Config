## Spec

Depends on `specs/program-platform-blocks.md`.

### Purpose

A program declares `excludeFromVpn = true;` once. Every VPN program installed on
a host then lets that program's traffic bypass the VPN. Mullvad implements the
contract through split tunneling. Steam is the first excluded program.

### Contract

VPN programs publish host facts through `hostConstants`, using the
set-by-import pattern in `docs/explanation/host-facts.md`. Each VPN sets its
entries in its own `systemConfig`, beside the enable that installs it. Homes
read the facts through the existing read-through.

- `hostConstants.vpn.excludeCommands` (Linux): a list of shell lines, default
  `[]`. Each line excludes the current shell process, `$$`, from one VPN. A
  line must not fail the launch when its VPN is unavailable.
- `hostConstants.vpn.syncExcludedApps` (macOS): a list of commands, default
  `[]`. Each command takes a state-file path followed by zero or more
  executable paths. It makes the VPN exclude exactly those paths for that
  state file's owner and leaves other entries alone.

Declare both facts in the existing host-constants schema.

### Linux: generated wrappers

When a program has `excludeFromVpn = true` and the host's
`hostConstants.vpn.excludeCommands` is not empty, the program's install adds a
higher-priority (`lib.hiPrio`) wrapped copy of its package. This applies to
the `"system"`, `"custom"`, and `"home"` ways.

- Package choice: `config.programs.<name>.package` when that option exists in
  the module system that installs the program. Otherwise use the effective
  `packages` when `hasEnableOption = false`. Otherwise use `pkgs.<name>`.
- Each executable in `bin/` becomes a script. The script runs every
  `excludeCommands` line, then runs `exec <original executable> "$@"`. Because
  `exec` keeps the process ID, the program and its children inherit the
  exclusion.
- Desktop entries whose `Exec` names the original store path are rewritten to
  the wrapper's path. Other files link to the original.
- With an empty command list, or without the flag, the install is unchanged.

### macOS: activation sync

When the host's `hostConstants.vpn.syncExcludedApps` is not empty, activation
runs each sync command with that writer's state file and the executable paths
of its excluded programs.

- System activation (nix-darwin) owns the excluded programs that resolve to
  `"cask"` or `"custom"` on the host. For a cask, read the app bundle name with
  `brew info --cask --json=v2 <token>`, then read `CFBundleExecutable` from the
  bundle's `Info.plist`. The executable path is
  `<bundle>/Contents/MacOS/<CFBundleExecutable>`.
- Home activation owns the excluded programs that resolve to `"home"`. It
  resolves each package's `Applications/*.app` in the Nix store the same way.
- A macOS `"custom"` way cannot be resolved reliably, because its
  `systemConfig` may install either a cask or a Nix package. Evaluation fails
  when a program with `excludeFromVpn` resolves to `"custom"` on a macOS host
  whose `syncExcludedApps` is not empty. The message names the program and
  states that macOS exclusion supports `"cask"` and `"home"` installs.
- A missing bundle or an unavailable VPN prints a warning and does not fail
  activation.
- With no excluded programs, the sync still runs with an empty list, so it
  removes the entries that the writer added before.

### Mullvad

Replace the current work-in-progress declaration in
`modules/programs/mullvad-vpn/mullvad-vpn.nix`.

- `shared.config.programs.mullvad-vpn.enable = true`. Leave home-manager's
  `settings` empty.
- Linux: `install = [ "custom" ]`. Its `systemConfig` sets
  `services.mullvad-vpn.enable`, `services.mullvad-vpn.gui.enable`, and
  `services.mullvad-vpn.enableEarlyBootBlocking` to `true`. It appends
  `mullvad split-tunnel add $$` to `hostConstants.vpn.excludeCommands`, guarded
  so that a failure does not stop the launch.
- macOS: `install = [ "cask" ]`. Its `systemConfig` appends a sync command to
  `hostConstants.vpn.syncExcludedApps`. The command calls
  `/usr/local/bin/mullvad`, which the cask's installer links. First it removes
  each path that the state file records and the new list omits. Then it adds
  the listed paths and records them in the state file. When the list is not
  empty, it runs `mullvad split-tunnel set on`.
- Hosts: `mullvad-vpn` stays in `globalPrograms` on redwood, spruce, and aspen.
  Cedar does not get it.

### Steam

- Steam's declaration: `linux.install = [ "custom" ]` with
  `linux.systemConfig.programs.steam.enable = true`. Keep
  `macos.install = [ "cask" ]`. Set `excludeFromVpn = true`.
- Redwood adds `"steam"` to `globalPrograms`. Its other `programs.steam`
  settings stay in redwood's host config.
- Remove the work-in-progress exclusion code: redwood's `extraPreBwrapCmds`
  hook, aspen's `services.mullvad-vpn.excludedApps`, and Mullvad's
  `excludedApps` option. That code passed `/Applications/Steam.app` to the
  CLI. The daemon matches exact executable paths, so that entry never matched.

### Documentation

- Replace `docs/explanation/mullvad-split-tunneling.md` with an explanation of
  the contract, the Linux wrapper, and the macOS sync.
- Update `docs/how-to/set-up-mullvad-vpn.md` for the new mechanism. Steps to
  exclude another app reduce to setting `excludeFromVpn = true`.
- Update `docs/reference/declaration-schema.md` for `excludeFromVpn`,
  `docs/explanation/host-facts.md` for the two facts, and
  `docs/reference/feature-index.md` for Mullvad and Steam.

### Non-goals

- Excluding a program on some hosts only.
- VPNs other than Mullvad.
- Launches that call a store path directly, which bypass the wrapper.
- Automating macOS Full Disk Access or the Mullvad account login.

### Acceptance criteria

- `nix flake check` passes.
- The redwood and spruce systems and their `jakeneau` homes build. The aspen
  and cedar systems and their homes evaluate.
- Redwood's system path resolves `bin/steam` to a wrapper that contains the
  Mullvad line and then runs `exec` on the real Steam. That real Steam is
  `config.programs.steam.package`, including Proton-GE and the configured fonts.
  `steam-run` is not wrapped.
- Spruce has Mullvad and no Steam wrapper.
- Aspen's activation runs Mullvad's sync command and resolves `steam` through
  `brew info` and `Info.plist`. Cedar has no Mullvad cask and no sync.
- These checks need the user's switched machines: Steam's `/proc/<pid>/cgroup`
  on redwood lists `mullvad-exclusions`, and `mullvad split-tunnel get` on
  aspen lists Steam's executable.

## Plan

## Tasks
