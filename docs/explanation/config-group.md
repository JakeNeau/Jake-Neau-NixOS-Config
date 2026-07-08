# The config-group trust model

Why repo write access works the way it does
(`modules/host-config/config-group/config-group.nix`). The one-time ACL
setup lives in the [bootstrap guide](../how-to/bootstrap-machine.md).

## The problem

The repo lives at a root-owned path (`/etc/nixos`, `/etc/nix-darwin`), so
by default editing it needs sudo — hostile to the model where every user
maintains their own `modules/users/<user>/` folder and rebuilds their own
home. But simply making the tree world- or user-writable would hand the
*system* config to anyone with an account.

## The model: explicit membership, whole-tree write

A `config` group owns the tree (the owner stays root; members get write
via ACLs). Two deliberate properties:

- **Membership is explicit, never inherited.** Users get no write access
  until listed by name, so adding a future user never silently grants them
  the config. On NixOS the member list is central
  (`config-group.nix`); on macOS account names differ per host, so each
  host aspect lists its own members while the shared aspect keeps only the
  group mechanics (`users.knownGroups`, gid 600 — the first free custom
  gid below Apple's sharepoint groups at 701/702).
- **Membership grants write to the *whole* tree, including `.git` and the
  system config.** There is no per-folder containment: any member can edit
  any folder, commit, and change what the machines run. That is the
  accepted trust model — the group answers "who administers the system
  config", not "who may edit their own corner". The `.git` write is
  load-bearing: flake eval ignores untracked files, so users must `git
  add` their own new files before `hr` sees them.

Grant membership deliberately; the design makes the grant impossible to
give by accident, not small.

## Why the ACL step is imperative

The group itself is declarative, but converting a root-owned checkout into
a group-writable one is a one-time filesystem step per machine: file ACLs
aren't recorded by git, and doing it from Nix would take a recursive chown
that would also clobber `secrets/`. So the sequence runs once after the
group exists (details in the bootstrap guide), and again on any fresh
clone.
