# The config-group trust model

Why repo write access works the way it does
(`modules/host-config/config-group/config-group.nix`). The [bootstrap guide](../how-to/bootstrap-machine.md) contains the one-time ACL
setup. The [repair procedure](../how-to/repair-config-group-access.md) covers
machines that predate its correction.

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
Re-running it with the corrected rights leaves two entries on every node whose
old entry was inherited. An explicit entry for the same identity merges
instead. The original grant relied on inheritance, so doubling is the normal
case here. The new explicit entry lands beside the old narrow one, still
present as an inherited entry. Both are `allow` entries, so their rights union
and access works.

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
CLI accepts an `/etc/nix-darwin` entry for that path and libgit2 does not. The
declarative config therefore uses the `/private` spelling. The temporary entry
a new user adds at bootstrap must also use it. On NixOS `/etc/nixos` is a
real directory, so the question never arises.

That temporary entry is the reason bootstrap ends by deleting `~/.gitconfig`.
The `git config --global` command writes there, git reads that file after the
managed `~/.config/git/config`, and the later file wins every conflict. So
anything left behind silently overrides the declarative git config. A stray
`~/.gitconfig` here duplicated `user.name` and `user.email` for weeks before
anyone noticed, which is why home activation now warns whenever the file
exists.

## Why git keeps new `.git` entries group-writable

The ACL fixes the tree as it stands. It does not govern what git writes next.
Every commit and fetch creates fresh files under `.git`. Each one lands under
the umask of the process that wrote it. The `nr` flow runs its git calls as
root through `sudo`, and root's umask 022 clears the group-write bit. So the
tree decays on every rebuild, until some member meets a file they cannot write.

`core.sharedRepository = "group"` is git's own answer. It makes git set the
group-write bit on what it creates inside `.git`, whatever the umask says.
Under umask 022 a new `.git/objects/<xx>` comes out `drwxrwxr-x` with the
setting and `drwxr-xr-x` without. The git module
(`modules/programs/git/git.nix`) therefore sets it, but only for these
repositories. Set globally, it would loosen permissions on every repository the
user owns. `includes` with a `gitdir:` condition supplies that scoping.

### The two path rules are not the same rule

Both the `gitdir:` conditions and libgit2's `safe.directory` allowlist need the
`/private` spelling on macOS, which makes them look like one fact. They are
two, with separate mechanisms. Reasoning from either to the other gives wrong
answers.

Git matches a `gitdir:` condition against the repository's resolved real path.
On macOS `/etc` is a symlink to `/private/etc`, so the real path is
`/private/etc/nix-darwin`, and only that spelling matches. It then matches
under every way of reaching the repository: the `sudo git -C /etc/nix-darwin`
form `nr` uses, a working directory at the repo root, and any subdirectory. On
Linux `/etc/nixos` is a real directory, so it resolves to itself. The trailing
slash is mandatory either way. Without it the condition has to match the `.git`
path itself rather than stand as a directory prefix, and nothing matches.

The `safe.directory` rule is a different question, covered above under "Why
libgit2 needs the `/private` path on macOS". It governs which process may open
the repository at all, libgit2 enforces it rather than the git CLI, and the CLI
accepts either spelling. Keep the two apart when changing either list.

### What the setting does not do

Three boundaries matter when reading a permission problem in this tree. The
setting only touches files git creates under `.git`, leaving the working tree
to the umask and the ACL. It only applies at creation time, so a file that is
already group-unwritable stays that way until someone runs `chmod g+w` over it.
And it is inert unless the git process reads a config file that sets it.

That last boundary splits by platform. The setting lives in the user's
home-manager git config, so root-run git picks it up only when `sudo` preserves
`HOME`. macOS `/etc/sudoers` carries `env_keep += "HOME MAIL"`, so it does. The
`nr` flow therefore leaves every root-run Git command in that form. Its separate
flake-update command uses `sudo -H` because root-run Nix rejects a user-owned
home directory.

NixOS generates sudoers without `env_keep HOME`. Root-run git there reads root's
own config and this include never fires. That is why the NixOS half remains
unfinished rather than assumed to work.
