# The config-group trust model

Why repo write access works the way it does
(`modules/host-config/config-group/config-group.nix`). The one-time ACL
setup, and the repair procedure for machines that predate its correction, live
in the [bootstrap guide](../how-to/bootstrap-machine.md).

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

## Why the ACL repair strips before it reapplies

macOS `chmod +a` appends an entry rather than editing an existing one.
Re-running it with the corrected rights leaves two entries on every node. The
new explicit one lands beside the old narrow one, still present as an inherited
entry. Both are `allow` entries, so their rights union and access works.

What breaks is the audit. The known-broken `list,add_file,search` grant still
sits in the output of `ls -lde`, so the next reader cannot tell a repaired tree
from a broken one. Cedar carried that doubled state on 677 of its 796 nodes.

Deleting the stale entry directly is not an option either. The `-a` flag takes
a list of rights, not an entry to erase, and it subtracts those rights from
whatever matches. Handed the old entry's own text, it strips
`read,write,execute` and leaves nothing but the delete rights. That is worse
than the state it was meant to repair.

That leaves `chmod -R -N` followed by a single `+a`, which is what the repair
procedure runs. It lands exactly one correct entry on every file and directory,
and inheritance still covers entries created later under umask 022. The `-N` is
indiscriminate, so it is safe only while `group:config` is the only thing any
ACL in the tree grants. That holds here by construction, and the procedure
checks it anyway.

## Why libgit2 needs the `/private` path on macOS

`nix` opens this repository through libgit2, not through the git CLI, and the
two match `safe.directory` entries differently. On macOS `/etc` is a symlink
to `/private/etc`, so the repo's real path is `/private/etc/nix-darwin`. The
CLI accepts an `/etc/nix-darwin` entry for that path and libgit2 does not. So
the declarative config lists the `/private` spelling too, and the temporary
entry a new user adds at bootstrap has to use it. On NixOS `/etc/nixos` is a
real directory, so the question never arises.

That temporary entry is the reason bootstrap ends by deleting `~/.gitconfig`.
The `git config --global` command writes there, git reads that file after the
managed `~/.config/git/config`, and the later file wins every conflict. So
anything left behind silently overrides the declarative git config. A stray
`~/.gitconfig` here duplicated `user.name` and `user.email` for weeks before
anyone noticed, which is why home activation now warns whenever the file
exists.
