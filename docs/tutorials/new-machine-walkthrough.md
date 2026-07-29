# New-machine walkthrough

In this lesson you'll take a machine from a bare operating system to its first
successful rebuild from this flake, declaring it as a new host along the way.
By the end the machine is fully managed: system config from Nix, your home
from home-manager, and the repo editable without `sudo`.

The macOS and NixOS paths differ at the start (getting Nix and the repo in
place) and converge once the host is declared. Follow the section for your
platform, then continue from [Declare the host](#2-declare-the-host).

Pick a hostname before you start — the repo names machines after trees
(aspen, cedar, redwood, spruce). We'll write `<host>` throughout.

## 1a. Bare OS to repo — NixOS

1. Install NixOS from an [image](https://nixos.org/download/). Flash it onto a
   USB stick — on a *nix system:

   ```sh
   dd if=/path/to/your/isofile of=/your/usb/disk bs=8M status=progress
   ```

2. After the installer finishes, replace the generated config with a clone of
   this repo:

   ```sh
   cd /etc/nixos/
   sudo rm -f configuration.nix
   sudo git clone https://github.com/jakeneau/Jake-Neau-NixOS-Config.git
   sudo sh -c 'mv ./Jake-Neau-NixOS-Config/* . && mv ./Jake-Neau-NixOS-Config/.* . 2>/dev/null; rm -rf ./Jake-Neau-NixOS-Config'
   ```

3. Place the sops age key at `secrets/keys.txt` (copied from another machine
   or your key backup — it is never in git) and lock it down:

   ```sh
   sudo chmod 600 /etc/nixos/secrets/keys.txt
   ```

   Without it the build cannot decrypt `secrets/secrets.yaml` (user password
   hashes live there).

4. Capture the machine's hardware config. The installer already generated
   one:

   ```sh
   cat /etc/nixos/hardware-configuration.nix
   ```

   Keep this output — in step 2 you'll fold it into the host's `hardware.nix`.

## 1b. Bare OS to repo — macOS

1. Install [Nix](https://nixos.org/download/) with flakes enabled (the
   standard multi-user installation).

2. Clone the repo to `/etc/nix-darwin`:

   ```sh
   sudo git clone https://github.com/jakeneau/Jake-Neau-NixOS-Config.git /etc/nix-darwin
   ```

   No sops key step: the darwin hosts don't consume sops secrets at build
   time (the key stays outside the repo on macOS and is only needed to *edit*
   secrets).

3. Make sure your macOS account exists and note its short name — on macOS the
   account itself is created in System Settings, never by Nix; nix-darwin only
   records its home directory.

## 2. Declare the host

Every host is two things in one file,
`modules/hosts/<host>/configuration.nix`: a `flake.hosts.<host>` declaration
(the structured facts the generator wires everything from) and a hand-written
aspect (the machine's quirks). Model yours on the closest existing host —
`spruce` for a Linux laptop, `aspen` for a Mac. A minimal macOS example:

```nix
{inputs, ...}: {
  flake.hosts.<host> = {
    class = "darwin";                                # or "nixos"
    system = "aarch64-darwin";                       # the platform
    users = ["<you>"];                               # accounts on this machine
    globalPrograms = ["ghostty" "firefox" "fastfetch"];
    baselines = ["role-desktop" "mac-app-util"];     # homeManager aggregates
  };

  flake.modules.darwin.<host> = {
    imports = [inputs.self.modules.darwin.role-desktop];

    hostConstants.hostName = "<host>";
    hostConstants.isLaptop = true;
    hostConstants.graphicsType = "apple";

    # repo write without sudo; the group itself comes from
    # modules/host-config/config-group
    users.groups.config.members = ["<you>"];
  };
}
```

Notes as you adapt it:

- `hostConstants.hostName` and `hostConstants.graphicsType` have no defaults —
  every host must declare them.
- **NixOS only:** the hand-written aspect also needs
  `system.stateVersion = "<the release you're installing>";`, and the hardware
  config from step 1a goes in `modules/hosts/<host>/hardware.nix` as a second
  contribution to the same `flake.modules.nixos.<host>` aspect (see
  `modules/hosts/spruce/hardware.nix` for the exact shape). The `config`
  group's member list on NixOS is central, in
  `modules/host-config/config-group/config-group.nix`, not per-host.
- The declaration fields are covered in the
  [adding-a-host guide](../how-to/declarations/add-a-host.md) and the
  [declaration schema reference](../reference/declaration-schema.md).

## 3. Stage and dry-build

New files are invisible to flake evaluation until staged:

```sh
sudo git add modules/hosts/<host>/
```

The commands below are the first you run as yourself rather than through `sudo`.
So let git open the root-owned repo first, with one command from the
[bootstrap guide](../how-to/bootstrap-machine.md#let-git-open-the-root-owned-repo-per-user).
Without it every `nix` command here fails on repository ownership.

Then prove the new host evaluates and builds without activating anything:

```sh
nix flake check
nix build .#darwinConfigurations.<host>.system --no-link          # macOS
nix build .#nixosConfigurations.<host>.config.system.build.toplevel --no-link  # NixOS
```

Fix anything that fails before going further — a throw here names the
declaration at fault and the fix.

## 4. First rebuild

macOS (the first run bootstraps `darwin-rebuild` itself; afterwards plain
`darwin-rebuild switch --flake /etc/nix-darwin` works):

```sh
sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake /etc/nix-darwin#<host>
```

NixOS:

```sh
sudo nixos-rebuild switch --flake /etc/nixos#<host>
```

When this finishes, the machine is running your declared configuration — and
the `config` group now exists on the system.

## 5. Make the repo editable without sudo

Run the one-time ACL sequence from the
[bootstrap guide](../how-to/bootstrap-machine.md) — it hands the repo tree to
the `config` group so members edit it directly. Then log out and back in (or
`newgrp config`) so your membership takes effect.

## 6. Activate your home

Your home configuration is separate from the system and is activated by you.
The very first activation is a bootstrap: the `home-manager` CLI (and the `hr`
function that wraps it) are themselves delivered *by* your home, so neither
exists yet. Run home-manager ad hoc this once:

```sh
nix run github:nix-community/home-manager -- switch -b backup --flake /etc/nix-darwin#<you>@<host>
```

(`/etc/nixos` on Linux.) From now on your home ships the CLI and the fish
`hr` function, so every later rebuild is just:

```sh
hr
```

Log out and in once more for a fully clean slate, and you're done: system and
home both build from the flake, and you can edit the repo in place.

## Where to next

- Commit the new host and let `nr` (the full verify-commit-push-rebuild flow)
  take over day-to-day rebuilds.
- Your first at-home change: [Your first home rebuild](first-home-rebuild.md).
- macOS extras that need one-time manual approval (Karabiner):
  [bootstrap guide](../how-to/bootstrap-machine.md).
