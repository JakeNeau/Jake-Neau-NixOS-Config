# VPN exclusion and Mullvad split tunneling

A program declares `excludeFromVpn = true;` once. Every VPN installed on a host
then lets that program's traffic bypass the tunnel. Mullvad is the only VPN
here, and it implements the contract through split tunneling. Steam is the
first excluded program. Steam and every game it starts therefore use the home
connection, and game servers see the home IP address. DNS still goes through
Mullvad.

## The contract: VPNs publish host facts

A program should not need to know which VPNs exist. Each VPN therefore
publishes how to exclude a program as a host fact. Its `systemConfig` sets the
fact beside the enable that installs it. This is the set-by-import pattern from
[host facts](host-facts.md). Installing the VPN on a host is what turns the
exclusion on.

- `hostConstants.vpn.excludeCommands` is a Linux list of shell lines. Each
  line excludes the current shell process, `$$`, from one VPN.
- `hostConstants.vpn.syncExcludedApps` is a macOS list of commands. Each one
  receives a state file and a list of executable paths. It makes its VPN
  exclude exactly those paths for the state file's owner.

The program generator reads both facts. Homes read them through the
read-through, so a home install gets the same behavior as a system install.

## Linux: a wrapper that excludes its own process

On Linux the Mullvad daemon keeps no list of excluded apps. It excludes
processes instead. The `mullvad split-tunnel add <pid>` command moves a
process into the `mullvad-exclusions` cgroup. Children inherit the cgroup, so
every process the program starts stays excluded. The daemon's management
socket accepts unprivileged users, so the wrapper needs no setuid helper.

For each excluded program the generator installs a wrapped copy of its
package. Each executable in `bin/` becomes a short script. The script runs
every exclude line and then runs `exec` on the original executable. The
`exec` keeps the process ID, so the cgroup move applies to the program
itself. Mullvad's line ends in `|| true`, so a stopped daemon never blocks a
launch.

The wrapped copy has a higher priority (`lib.hiPrio`) than the original.
NixOS ignores collisions in the system path, so at equal priority whichever
package merges in first wins. Priority makes the choice explicit. Desktop entries that name the
original store path point at the copy. Steam's entries call `steam` by name,
so they reach the wrapper through `PATH`.

For Steam, the generator wraps the package that the NixOS Steam module
builds. That package, `config.programs.steam.package`, includes Proton-GE and
the configured fonts.
`steam-run` is a separate package, so programs started with it stay in the
tunnel. Steam runs one instance at a time, so the first launch decides
whether Steam bypasses the tunnel. The wrapper covers that launch from the
menu, a `steam://` link, or the gamescope session. Launching a store path directly
skips the wrapper.

An earlier version hooked Steam's launcher before bubblewrap and re-ran it
through the setuid `mullvad-exclude`. That needed guards against loops and
against `steam-run`. The wrapper needs neither.

## macOS: activation syncs executable paths

On macOS the daemon stores a list of excluded executable paths. It matches a
process's exact executable path. An entry like `/Applications/Steam.app`
therefore never matches. The entry must be the bundle's executable,
`<bundle>/Contents/MacOS/<CFBundleExecutable>`.

Activation finds that path for each excluded program:

- System activation covers programs installed as casks. It asks
  `brew info --cask --json=v2` for the app bundle name. Then it reads
  `CFBundleExecutable` from the bundle's `Info.plist`.
- Home activation covers per-user installs. It reads each package's
  `Applications/*.app` bundle in the Nix store the same way.

A `"custom"` install on macOS fails evaluation when the host has a sync
command. Its `systemConfig` may install a cask or a Nix package, so no rule
can find its executable reliably.

Each writer passes its own state file to every sync command. System
activation uses `/var/db/vpn-excluded-apps`, and each home uses
`~/.local/state/vpn-excluded-apps`. Mullvad's command removes the paths that
the state file records and the new list omits. Then it adds the new paths,
records them, and turns split tunneling on when the list is not empty. Apps
that you exclude in the Mullvad app stay excluded, because no state file
records them. The sync runs even with an empty list, so removing
`excludeFromVpn` takes the program out at the next activation.

A missing bundle or a stopped daemon prints a warning and does not fail
activation. Split tunneling also needs Full Disk Access, which only the user
can grant. See [Set up Mullvad VPN](../how-to/set-up-mullvad-vpn.md).

## Why home-manager's Mullvad settings stay empty

Home-manager's `programs.mullvad-vpn` module writes only the app's
`gui_settings.json`, which holds window preferences. Its
`browsedForSplitTunnelingApplications` key lists the apps that the app's
picker displays. The app never sends that list to the daemon. Declaring it
would therefore exclude nothing. Home-manager would also link the file
read-only into the Nix store, so the app could no longer save its own
preferences.
