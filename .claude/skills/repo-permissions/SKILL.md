---
name: repo-permissions
description: How write access to this root-owned Nix config repo works, and how to check it is set up on the current machine. This repo (/etc/nixos) stays owned by root; a dedicated `config` group owns the tree so its members can edit without sudo. Use when editing files here, when a file edit fails with "permission denied" / EACCES, or when setting up the repo on a new machine or fresh clone — and proactively tell the user if the setup is missing so they are not stuck using sudo for every edit.
---

# Repository write access (the `config` group)

This config lives at a **root-owned path** (`/etc/nixos` on NixOS). To allow
editing without `sudo` while keeping the tree root-owned — so a freshly added
system user gets **no** access until granted it — a dedicated **`config` group**
owns the tree and has write access via group permissions + POSIX ACLs.

- Declared dendritically in `modules/system/config-group/config-group.nix`
  (`flake.modules.nixos.config-group` → `users.groups.config.members`), imported
  into `flake.modules.nixos.system-default` so every NixOS host gets the group.
- Membership is **current users only**, listed explicitly — it is deliberately
  *not* baked into the user factory, so new users do not auto-gain write access.
- NixOS-only: `/etc/nixos` does not exist on macOS (config there is at
  `/etc/nix-darwin`), and this repo does not manage macOS groups.

## Why this matters to you (the agent)

When the `config` group setup is in place **and** your session has picked up the
membership, your native `Edit`/`Write` tools work directly on `/etc/nixos`. When
it is **not** set up (a new machine, a fresh clone, or a user who never ran it),
every edit fails on permissions and you fall back to clumsy `sudo tee` / `sudo
perl` editing, which is slow and prone to shell-quoting bugs.

So: **check early, and surface the gap to the user** rather than silently
sudo-editing forever.

## How to check whether it is set up

Run these (read-only):

```sh
getent group config                 # 1. does the group exist on this machine?
ls -ld /etc/nixos                    # 2. group should be `config`, perms `drwxrwsr-x+`
getfacl -p /etc/nixos | grep config # 3. should show group:config:rwx AND default:group:config:rwx
id -nG | grep -qw config && echo "member-active" || echo "member-INACTIVE"  # 4. this session
```

Interpretation:

- **Group missing (1)** or **tree not `config`-owned / no ACL (2,3)** → setup has
  **not** been done on this machine. Tell the user and offer the steps below. Do
  not just keep sudo-editing.
- **Set up but step 4 says `member-INACTIVE`** → the setup is done, but the
  current login session predates the group's creation. The user must **log out
  and back in** (and relaunch Claude) for membership to take effect; until then
  native edits here still need `sudo`.
- **All four good** → edit with native tools; no `sudo` needed.

## How to set it up (hand these to the user)

The declarative group must exist on the system first, then the filesystem is
adjusted once. The agent must **not** run the rebuild (it activates the system
and `nr`/`nrr` also push to GitHub) — that is the user's to run.

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

## Caveats

- **Secrets.** `secrets/keys.txt` (the sops age key) must stay `-rw-------`
  (`chmod 600`). The default ACL would otherwise make a *newly created* key
  group-readable, so if the key is ever rotated (deleted + recreated rather than
  edited in place), re-run `chmod 600 secrets/keys.txt`.
- **Membership changes need re-login.** Adding a user to `config` (or the initial
  setup) only takes effect in sessions started afterward.
- Still **never** run `switch`, `nr`/`nrr`, or `nix flake update`, and never
  push — see `AGENTS.md` and the `nix-config` skill.
