# Add a user

Give a person an account, a home configuration, and (optionally) the right to
edit this repo.

## 1. macOS only: create the account imperatively

Create the account in System Settings first. nix-darwin never creates
accounts. The factory only records the home directory
(`modules/factory/user/user.nix`). On NixOS, skip this step because the account
is fully declarative.

## 2. Create the user's folder and factory stamping

Make `modules/users/<user>/<user>.nix`:

```nix
{inputs, ...}: {
  flake.modules = inputs.self.factory.user "<user>" <isAdmin>;
}
```

The factory stamps the account aspects (`nixos.<user>` / `darwin.<user>`),
the `homeManager.<user>` aspect, and the `~/.config/nix-config` symlink to
this folder.

NixOS sets `users.mutableUsers = false`. Every NixOS account must declare
a password hash or an authorized SSH key before its first system activation.
An administrator needs a password hash for local login and `sudo`. The factory
alone creates a locked account. Follow [Add a secret](add-a-secret.md) and model
the `hashedPasswordFile` layer on `modules/users/jakeneau/jakeneau.nix`.

A user who will edit `secrets/secrets.yaml` needs `"secrets-management"`
in their `flake.users.<user>.programs`. That program installs the `sops` and
`age` commands in their home.

## 3. List the user on their host(s)

In each host's `flake.hosts.<host>` declaration
(`modules/hosts/<host>/configuration.nix`):

```nix
users = ["<user>"];
```

This one line is the single authority: it yields the account placement, the
host's baseline delivery to that home, and the
`homeConfigurations."<user>@<host>"` output.

## 4. Grant config-group membership (optional)

Only if this user should edit the repo:

- **macOS:** add them to the host aspect's member line,
  `users.groups.config.members = [...]`, in
  `modules/hosts/<host>/configuration.nix` (member lists are per-host on
  darwin because account names differ per machine).
- **NixOS:** add them to the central list in
  `modules/host-config/config-group/config-group.nix`.

Membership grants write to the *whole* tree, including `.git` and the system
config. Grant it deliberately.

## 5. Stage, verify, rebuild

```sh
git add modules/users/<user>/
nix flake check
nix build '.#homeConfigurations."<user>@<host>".activationPackage' --no-link
```

Then rebuild the system (the owner's `nr` flow, or a plain
`nixos-rebuild`/`darwin-rebuild switch`). The system rebuild creates the NixOS
account and registers the group membership.

## 6. The new member logs out and in

Group membership only takes effect on a fresh login (`newgrp config` works
for a single shell). The user activates their own home the first time with the
ad-hoc bootstrap command (see
[platform bootstrap procedure](../bootstrap-machine.md)),
`hr` from then on. Before that first command they must add the root-owned
repository to Git's safety list as shown in the same procedure.
Without it their first `nix` command against the flake fails on repository
ownership. Point them at the
[first home rebuild tutorial](../../tutorials/first-home-rebuild.md).
