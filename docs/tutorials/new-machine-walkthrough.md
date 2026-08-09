# New-machine walkthrough

This lesson takes a machine from an installed operating system to its first successful rebuild from this flake.

You will declare a new host, activate its system, activate its user home, and grant repository access.

Choose a tree name for `<host>`. Use the existing macOS account name or NixOS user declaration for `<user>`.

## 1. Reach the repository

Follow the platform procedure through the repository clone:

- [NixOS installation and clone](../how-to/bootstrap-machine.md#nixos)
- [macOS installation and clone](../how-to/bootstrap-machine.md#macos)

On NixOS, the clone procedure preserves the generated hardware file at:

```text
/etc/nixos-installer/hardware-configuration.nix
```

Do not delete that directory before creating the host hardware module.

Set the repository path for the remaining commands:

```sh
# NixOS
cd /etc/nixos
# macOS uses this path instead.
# cd /etc/nix-darwin
```

## 2. Confirm the user declaration

Use Nix-provided ripgrep to find the account name:

```sh
sudo nix --extra-experimental-features 'nix-command flakes' run nixpkgs#ripgrep -- \
  'flake\.users\.<user>|flake\.users\."<user>"' modules/users
```

If the command finds no declaration, create its directory and follow [Add a user](../how-to/declarations/add-a-user.md):

```sh
sudo mkdir -p modules/users/<user>
```

A NixOS administrator must have a SOPS-managed password hash before the first activation. NixOS locks an immutable account that has no hash.

On macOS, create the account in System Settings first. nix-darwin records existing macOS accounts but never creates them.

Before the first system activation, edit every repository file with `sudo`. The `config` group does not exist yet.

A fresh machine can open a temporary editor through Nix:

```sh
sudo nix --extra-experimental-features 'nix-command flakes' run nixpkgs#vim -- <file>
```

## 3. Declare the host

Create the host directory:

```sh
sudo mkdir -p modules/hosts/<host>
```

Open `modules/hosts/<host>/configuration.nix` with the temporary editor. Model it on `spruce` for NixOS or `aspen` for macOS.

A minimal macOS host has this shape:

```nix
{inputs, ...}: {
  flake.hosts.<host> = {
    class = "darwin";
    system = "aarch64-darwin";
    users = ["<user>"];
    globalPrograms = ["ghostty" "firefox" "fastfetch"];
    baselines = ["role-desktop" "mac-app-util"];
  };

  flake.modules.darwin.<host> = {
    imports = [inputs.self.modules.darwin.role-desktop];

    hostConstants.hostName = "<host>";
    hostConstants.isLaptop = true;
    hostConstants.graphicsType = "apple";

    users.groups.config.members = ["<user>"];
  };
}
```

Check the machine architecture:

```sh
uname -m
```

Use `x86_64-linux` or `aarch64-linux` on NixOS. Use `x86_64-darwin` for an Intel Mac and `aarch64-darwin` for Apple silicon.

Adapt these required values:

- Set `class` to `"nixos"` or `"darwin"`.
- Set `system` to the matching Nix platform.
- Set `users` to declared accounts that belong on this host.
- Set `hostConstants.hostName` and `hostConstants.graphicsType`.
- Set `system.stateVersion` for NixOS.
- Add the macOS account to `users.groups.config.members`.
- Add the NixOS account centrally in `modules/host-config/config-group/config-group.nix`.

The [host declaration guide](../how-to/declarations/add-a-host.md) defines every required host field.

## 4. Add NixOS hardware configuration

Skip this section on macOS.

Read the preserved installer output:

```sh
cat /etc/nixos-installer/hardware-configuration.nix
```

Open `modules/hosts/<host>/hardware.nix`. Convert the generated module into a contribution to the host aspect.

Use `modules/hosts/spruce/hardware.nix` as the structural example. The result must have this outer shape:

```nix
{
  flake.modules.nixos.<host> = {
    config,
    lib,
    modulesPath,
    ...
  }: {
    # Copy the generated imports, boot, filesystem, swap, and platform settings here.
  };
}
```

Copy the generated hardware values exactly. Do not reuse another host's device UUIDs.

## 5. Format and stage the host

Format the new Nix files with a temporary Alejandra package:

```sh
sudo nix --extra-experimental-features 'nix-command flakes' run nixpkgs#alejandra -- \
  modules/hosts/<host>
```

Stage every new declaration before evaluation. Nix ignores untracked files in a Git flake.

```sh
sudo nix --extra-experimental-features 'nix-command flakes' run nixpkgs#git -- \
  -C "$PWD" add modules/hosts/<host>/ modules/host-config/config-group/config-group.nix modules/users/<user>/
```

Git ignores unchanged paths. The command also stages any user or NixOS group declaration created during this walkthrough.

## 6. Complete platform prerequisites

On NixOS, complete [Create and authorize an age key](../how-to/bootstrap-machine.md#3-create-and-authorize-an-age-key).

macOS does not consume SOPS secrets during system builds.

## 7. Allow user-level Nix evaluation

The repository is still root-owned. Add the correct path to the current user's temporary Git safety configuration.

On NixOS:

```sh
nix --extra-experimental-features 'nix-command flakes' run nixpkgs#git -- \
  config --global --add safe.directory /etc/nixos
```

On macOS:

```sh
nix --extra-experimental-features 'nix-command flakes' run nixpkgs#git -- \
  config --global --add safe.directory /private/etc/nix-darwin
```

libgit2 requires the `/private` spelling on macOS.

## 8. Check and build

Run every flake check:

```sh
nix --extra-experimental-features 'nix-command flakes' flake check
```

Build the new host without activating it.

On NixOS:

```sh
nix --extra-experimental-features 'nix-command flakes' build \
  .#nixosConfigurations.<host>.config.system.build.toplevel --no-link
```

On macOS:

```sh
nix --extra-experimental-features 'nix-command flakes' build \
  .#darwinConfigurations.<host>.system --no-link
```

Fix every error before activation.

## 9. Activate the system

On NixOS:

```sh
sudo env NIX_CONFIG='experimental-features = nix-command flakes' \
  nixos-rebuild switch --flake /etc/nixos#<host>
```

On macOS:

```sh
sudo nix --extra-experimental-features 'nix-command flakes' run \
  nix-darwin/master#darwin-rebuild -- \
  switch --flake /etc/nix-darwin#<host>
```

The activation creates the `config` group and applies the declared account membership.

## 10. Grant repository access

Run the platform's **Grant repository access** section in the [bootstrap guide](../how-to/bootstrap-machine.md).

Log out and back in after the permission commands. Confirm the new session contains the group:

```sh
groups | grep -w config
```

## 11. Activate the user home

Run Home Manager once through Nix.

On NixOS:

```sh
nix run github:nix-community/home-manager -- switch -b backup \
  --flake '/etc/nixos#"<user>@<host>"'
```

On macOS:

```sh
nix run github:nix-community/home-manager -- switch -b backup \
  --flake '/etc/nix-darwin#"<user>@<host>"'
```

The activation installs the managed `home-manager`, `git`, `hr`, and `nr` commands.

Delete the temporary unmanaged Git configuration:

```sh
rm -f ~/.gitconfig
```

## 12. Configure push access

Complete [Configure GitHub push access](../how-to/bootstrap-machine.md#configure-github-push-access).

Commit, verify, push, and rebuild the declared machine:

```sh
nr "Bootstrap <host>"
```

The machine is now fully managed. Future home rebuilds use `hr`, and verified system changes use `nr`.

## Where to next

- Make an at-home change with [Your first home rebuild](first-home-rebuild.md).
- Review all host fields in [Add a host](../how-to/declarations/add-a-host.md).
- Repair old repository permissions with [Repair config-group repository access](../how-to/repair-config-group-access.md).
