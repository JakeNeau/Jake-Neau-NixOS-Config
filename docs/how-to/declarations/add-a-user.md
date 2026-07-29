# Add a user

Give a person an account, a home configuration, and (optionally) the right to
edit this repo.

## 1. macOS only: create the account imperatively

Create the account in System Settings first — nix-darwin never creates
accounts; the factory only records the home directory
(`modules/factory/user/user.nix`). On NixOS skip this: the account is fully
declarative.

## 2. Create the user's folder and factory stamping

Make `modules/users/<user>/<user>.nix`:

```nix
{inputs, ...}: {
  flake.modules = inputs.self.factory.user "<user>" <isAdmin>;
}
```

The factory stamps the account aspects (`nixos.<user>` / `darwin.<user>`),
the `homeManager.<user>` aspect, and the `~/.config/nix-config` symlink to
this folder. Layer per-user extras on top with `lib.mkMerge` — see
`modules/users/jakeneau/jakeneau.nix` for the pattern (it adds a
sops-managed password on NixOS).

A user who will edit `secrets/secrets.yaml` needs `"secrets-management"`
in their `flake.users.<user>.programs` — that is what puts the `sops` and
`age` CLIs in their home. See [Add a secret](add-a-secret.md).

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

- **macOS:** add them to the host aspect's member line —
  `users.groups.config.members = [...]` in
  `modules/hosts/<host>/configuration.nix` (member lists are per-host on
  darwin because account names differ per machine).
- **NixOS:** add them to the central list in
  `modules/host-config/config-group/config-group.nix`.

Membership grants write to the *whole* tree, including `.git` and the system
config — grant it deliberately.

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
for a single shell). The user then activates their own home — the first time
with the ad-hoc bootstrap command (see
[first home activation](../bootstrap-machine.md#first-home-activation-per-user)),
`hr` from then on. Before that first command they must run
[let git open the root-owned repo](../bootstrap-machine.md#let-git-open-the-root-owned-repo-per-user).
Without it their first `nix` command against the flake fails on repository
ownership. Point them at the
[first home rebuild tutorial](../../tutorials/first-home-rebuild.md).
