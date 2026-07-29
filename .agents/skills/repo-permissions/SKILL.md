---
name: repo-permissions
description: How write access to this root-owned Nix config repo works, and how to check it is set up on the current machine. The repo (/etc/nixos on NixOS, /etc/nix-darwin on macOS) stays owned by root; a dedicated `config` group owns the tree so its members can edit without sudo. Use when editing files here, when a file edit fails with "permission denied" / EACCES, or when setting up the repo on a new machine or fresh clone — and proactively tell the user if the setup is missing so they are not stuck using sudo for every edit.
---

# Repository write access (the `config` group)

This config lives at a **root-owned path** (`/etc/nixos` on NixOS,
`/etc/nix-darwin` on macOS). To allow editing without `sudo` while keeping the
tree root-owned — so a freshly added system user gets **no** access until granted
it — a dedicated **`config` group** owns the tree with write access via group
permissions + ACLs.

- Declared dendritically in `modules/host-config/config-group/config-group.nix`,
  imported into each `role-default`:
  - **NixOS:** `flake.modules.nixos.config-group` → `users.groups.config.members`
    (`["jakeneau"]`) — the member list is central, shared by all NixOS hosts.
  - **macOS:** `flake.modules.darwin.config-group` carries only the group
    mechanics — `users.knownGroups = ["config"]` plus `users.groups.config.gid
    = 600` (nix-darwin only creates/manages a group that is in `knownGroups`
    and given an explicit gid). Account names differ per host, so **each host
    aspect lists its own members**: cedar lists `jake.neau`, aspen lists
    `jakeneau` (`users.groups.config.members` in
    `modules/hosts/<host>/configuration.nix`).
- Membership is **current users only**, listed explicitly — deliberately *not*
  baked into the user factory, so new users don't auto-gain write access.

## Why this matters to you (the agent)

With the `config` group set up **and** your session carrying the membership, your
native `Edit`/`Write` tools work directly on the repo. Without it (a new machine, a
fresh clone, or a user who never ran setup), every edit fails on permissions and
you fall back to clumsy `sudo tee` / `sudo perl` editing — slow and prone to
shell-quoting bugs.

So: **check early, and surface the gap to the user** rather than silently
sudo-editing forever.

## How to check whether it is set up

Read-only. **NixOS:**

```sh
getent group config                 # 1. does the group exist on this machine?
ls -ld /etc/nixos                    # 2. group should be `config`, perms `drwxrwsr-x+`
getfacl -p /etc/nixos | grep config # 3. should show group:config:rwx AND default:group:config:rwx
id -nG | grep -qw config && echo "member-active" || echo "member-INACTIVE"  # 4. this session
```

**macOS** (different tools — no `getent`/`getfacl`; ACLs show via `ls -lde`):

```sh
dscl . -read /Groups/config PrimaryGroupID         # 1. group exists? (expect gid 600)
ls -lde /etc/nix-darwin                            # 2. group `config`, perms `drwxrwsr-x+`, inheriting ACL line
dsmemberutil checkmembership -U "$(whoami)" -G config  # 3. "is a member" at OS level
id -nG | grep -qw config && echo member-active || echo member-INACTIVE  # 4. this session
```

Interpretation:

- **Group missing (1)** or **tree not `config`-owned / no ACL (2,3)** → not set up
  on this machine. Tell the user and offer the steps below; don't keep
  sudo-editing.
- **macOS, ACL present but narrow** → on a directory the ACE must name both
  `add_subdirectory` and `delete_child`, as in
  `list,add_file,search,delete,add_subdirectory,delete_child,…`. If it stops at
  `list,add_file,search,file_inherit,directory_inherit`, the tree was set up with
  the old short `read,write,execute` form, which grants neither. Writes then
  succeed while renames, deletes, and `mkdir` fail on any directory that has lost
  its group-write mode bit — so editors saving via temp-file-plus-rename fail and
  strand the temp file. Repair it in two steps:
  - **Immediate:** `sudo chmod -R g+w .` restores the mode bits.
  - **Durable:** run the strip-then-reapply procedure in
    [`docs/how-to/bootstrap-machine.md`](../../../docs/how-to/bootstrap-machine.md)
    under "Repair a machine bootstrapped before the corrected ACL" — `chmod -R -N`
    first, then one corrected `chmod -R +a`. Do **not** just re-run `chmod +a`. It
    merges only into an *explicit* entry for the same group, never into an
    inherited one. So every node that inherited the narrow entry keeps it beside
    the new one — 677 of cedar's 796 nodes. The next audit then cannot tell a
    repaired tree from a broken one. Never delete the
    leftover with `chmod -R -a "<the old ACE string>"` either: `-a` subtracts the
    rights you name rather than removing an entry, so it strips
    `read,write,execute` and breaks group access outright. A repaired node shows
    exactly **one** `group:config` entry. Two means the strip was skipped.
- **Set up but step 4 says `member-INACTIVE`** → setup is done but this session
  predates the group. On **NixOS** the user must **log out / back in** (and relaunch
  Claude). On **macOS** membership is evaluated dynamically (via `dsmemberutil`), so
  it is usually active immediately — if `id` still omits it but step 3 says "is a
  member", a fresh shell/session picks it up without a full logout.
- **All four good** → edit with native tools; no `sudo` needed.

## How to set it up

The canonical sequence — the rebuild that creates the group, then the one-time
filesystem ACL step per platform — lives in
[`docs/how-to/bootstrap-machine.md`](../../../docs/how-to/bootstrap-machine.md);
hand that to the user. Filesystem ACLs are not recorded by git, so **a fresh
clone needs the ACL sequence re-run** even on a bootstrapped machine. The agent
must **not** run the rebuild (it activates the system, and `nr`/`nrr` also push
to GitHub) — that is the user's to run; the ACL commands themselves are safe for
the agent to run with `sudo` once the group exists.

**macOS shortcut:** the group can be created imperatively *before* the rebuild,
so sudo-free editing works immediately — the rebuild then just adopts the
existing gid-600 group (it reads the existing gid and only creates when
missing). Agent, with `sudo`:

```sh
sudo dscl . -create /Groups/config
sudo dscl . -create /Groups/config PrimaryGroupID 600
sudo dscl . -create /Groups/config RealName "Nix config editors"
sudo dscl . -create /Groups/config Password "*"
sudo dscl . -append  /Groups/config GroupMembership <member>   # this host's declared member: jake.neau on cedar, jakeneau on aspen
```

Then run the bootstrap guide's macOS ACL block from the repo root.

## Caveats

- **Secrets.** `secrets/keys.txt` (the sops age key) must stay `-rw-------`
  (`chmod 600`). The default ACL would otherwise make a *newly created* key
  group-readable, so if the key is ever rotated (deleted + recreated rather than
  edited in place), re-run `chmod 600 secrets/keys.txt`.
- **Membership changes need re-login.** Adding a user to `config` (or the initial
  setup) only takes effect in sessions started afterward.
- Still **never** run `switch`, `nr`/`nrr`, or `nix flake update`, and never
  push — see `AGENTS.md` and [[skill:nix-config]].

## Related skills

- [[skill:nix-config]] — repo structure and the `config-group` feature module
