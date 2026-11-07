# Set up Mullvad VPN

Use this procedure after the first rebuild that installs Mullvad VPN on a
machine. The flake installs the client and its daemon. It cannot log in to
your account or grant macOS permissions.

## Log in on each machine

1. Log in. The command prompts for your Mullvad account number:

   ```sh
   mullvad account login
   ```

   The Mullvad app's login screen works too. Each login uses one of the
   account's device slots.

2. Connect and confirm the tunnel:

   ```sh
   mullvad connect
   curl https://am.i.mullvad.net/connected
   ```

   The response should confirm the Mullvad connection.

## Allow split tunneling on macOS

macOS split tunneling needs Full Disk Access for Mullvad VPN. Nix-darwin cannot
grant this permission.

1. Open System Settings > Privacy & Security > Full Disk Access.
2. Turn on Mullvad VPN. If the list lacks it, add it from `/Applications`.
3. Rebuild the machine. Activation then sends the executable of each excluded
   program to the daemon.
4. Confirm that the daemon has the list:

   ```sh
   mullvad split-tunnel get
   ```

   The output should show split tunneling on and list
   `/Applications/Steam.app/Contents/MacOS/` followed by Steam's executable
   name.

Mullvad notes that this permission can turn itself off. If excluded apps start
to use the tunnel again, remove Mullvad VPN from the Full Disk Access list, add
it again, and rebuild.

If activation printed a warning that Mullvad did not apply the exclusion,
start the Mullvad app and rebuild again.

## Confirm that Steam bypasses the tunnel on Redwood

1. Exit Steam completely:

   ```sh
   steam -shutdown
   ```

2. Start Steam normally.
3. Confirm that the Steam process is in Mullvad's exclusion group:

   ```sh
   grep mullvad-exclusions /proc/$(pgrep -xo steam)/cgroup
   ```

   The command should print one line.

## Exclude another program

1. Set `excludeFromVpn = true;` in the program's `flake.programs`
   declaration.
2. Rebuild the machine. For a per-user install, also rebuild your home with
   `hr`.

On macOS the program must install as a cask or per user. A `"custom"` install
fails evaluation. On Linux, start the program by its command name, because a
launch that calls a store path directly skips the wrapper.

See [VPN exclusion and Mullvad split
tunneling](../explanation/mullvad-split-tunneling.md) for how each platform
excludes a program.
