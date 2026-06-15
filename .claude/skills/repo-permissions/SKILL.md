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

- Declared dendritically in `modules/system/config-group/config-group.nix`,
  imported into each `system-default`:
  - **NixOS:** `flake.modules.nixos.config-group` → `users.groups.config.members`.
  - **macOS:** `flake.modules.darwin.config-group` → `users.knownGroups = ["config"]`
    plus `users.groups.config = { gid = 600; members = ["jake.neau"]; }`. nix-darwin
    only creates/manages a group that is in `knownGroups` and given an explicit gid.
- Membership is **current users only**, listed explicitly — deliberately *not*
  baked into the user factory, so new users don't auto-gain write access. The
  username differs by platform: `jakeneau` on NixOS, `jake.neau` on macOS.

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
- **Set up but step 4 says `member-INACTIVE`** → setup is done but this session
  predates the group. On **NixOS** the user must **log out / back in** (and relaunch
  Claude). On **macOS** membership is evaluated dynamically (via `dsmemberutil`), so
  it is usually active immediately — if `id` still omits it but step 3 says "is a
  member", a fresh shell/session picks it up without a full logout.
- **All four good** → edit with native tools; no `sudo` needed.

## How to set it up (hand these to the user)

The declarative group should exist on the system, then the filesystem is adjusted
once. The agent must **not** run the rebuild (it activates the system, and
`nr`/`nrr` also push to GitHub) — that is the user's to run.

### NixOS

1. **User runs the rebuild** (their normal `nr` flow) so the `config` group is
   created on the live system. (`nr` is a fish function — running it in a bash
   subshell fails with `command not found`; run it in fish, e.g. `! nr` from the
   Claude prompt.)
2. **One-time filesystem setup** (safe for the agent to run with `sudo` once the
   group exists — no rebuild, no push), from the repo root:

   ```sh
   sudo chgrp -R config .                       # group owns every file
   sudo chmod -R g+w .                          # members may write
   sudo find . -type d -exec chmod g+s {} +     # new files inherit the group
   sudo setfacl -R  -m g:config:rwX .           # existing files
   sudo setfacl -R -d -m g:config:rwX .         # default ACL keeps new files writable
   sudo chmod 600 secrets/keys.txt              # re-lock the sops age key afterwards
   ```
3. **User logs out / back in** (or reboots) so the session gains `config`
   membership; relaunch Claude.

### macOS

macOS has no `getfacl`/`setfacl`; ACLs are set with `chmod +a`. Because the group
can be created imperatively, the agent can bootstrap it **before** the rebuild and
the user gets sudo-free editing immediately — the rebuild then just adopts the
existing gid-600 group (it reads the existing gid and only creates when missing).

1. **Create the group** (agent, `sudo`) with the same gid the darwin aspect pins:

   ```sh
   sudo dscl . -create /Groups/config
   sudo dscl . -create /Groups/config PrimaryGroupID 600
   sudo dscl . -create /Groups/config RealName "Nix config editors"
   sudo dscl . -create /Groups/config Password "*"
   sudo dscl . -append  /Groups/config GroupMembership jake.neau
   ```
2. **One-time filesystem setup** (agent, `sudo`), from the repo root:

   ```sh
   sudo chgrp -R config .                       # group owns every file
   sudo chmod -R g+w .                          # members may write
   sudo find . -type d -exec chmod g+s {} +     # new files inherit the group
   sudo chmod -R +a "group:config allow read,write,execute,file_inherit,directory_inherit" .
   ```

   No `keys.txt` re-lock: the sops age key lives outside the repo on macOS, and
   the in-tree `secrets.yaml` is sops-encrypted (safe group-read).
3. **User runs the rebuild** (`nr`) at their convenience to formalize the group
   declaratively. Membership is usually live immediately (see check step 3/4); a
   fresh shell picks it up if `id` lags.

## Caveats

- **Secrets.** `secrets/keys.txt` (the sops age key) must stay `-rw-------`
  (`chmod 600`). The default ACL would otherwise make a *newly created* key
  group-readable, so if the key is ever rotated (deleted + recreated rather than
  edited in place), re-run `chmod 600 secrets/keys.txt`.
- **Membership changes need re-login.** Adding a user to `config` (or the initial
  setup) only takes effect in sessions started afterward.
- Still **never** run `switch`, `nr`/`nrr`, or `nix flake update`, and never
  push — see `CLAUDE.md` and the `nix-config` skill.
