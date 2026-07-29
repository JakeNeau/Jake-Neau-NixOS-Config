# Bootstrap a machine or fresh clone

Every one-time imperative step this config needs. Everything else is
declarative; if a step isn't listed here, a rebuild handles it.

For a full guided version (including declaring the new host), see the
[new-machine walkthrough](../tutorials/new-machine-walkthrough.md).

## Get the repo in place

- **NixOS:** clone into `/etc/nixos` (replacing the installer's
  `configuration.nix`).
- **macOS:** install Nix (multi-user, flakes enabled), then clone into
  `/etc/nix-darwin`.

First rebuild:

```sh
sudo nixos-rebuild switch --flake /etc/nixos#<host>                              # NixOS
sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake /etc/nix-darwin#<host>  # macOS, first run only
```

## Place the sops age key (Linux)

Copy the age private key (from another machine or your key backup — it is
never committed) to `secrets/keys.txt` and lock it down:

```sh
sudo chmod 600 /etc/nixos/secrets/keys.txt
```

The NixOS build needs it to decrypt `secrets/secrets.yaml`
(`modules/nix/tools/sops/sops.nix` reads it from
`/etc/nixos/secrets/keys.txt`).

**macOS:** no placement step. The darwin hosts consume no sops secrets at
build time; keep the key outside the repo, needed only to
[edit secrets](declarations/add-a-secret.md).

## The config-group ACL sequence

The `config` group owns the repo tree so members edit it without `sudo`.
The group itself is declared in Nix
(`modules/host-config/config-group/config-group.nix`), but converting a
root-owned checkout into a group-writable one is a one-time imperative
filesystem step.

Because filesystem ACLs are not recorded by git, **a fresh clone needs this
sequence re-run** even on an already-bootstrapped machine.

Run it once from the repo root, *after* the group exists on the system (i.e.
after the first rebuild), then log out/in (or `newgrp config`).

Linux (`/etc/nixos`) — POSIX ACLs via setfacl:

```sh
sudo chgrp -R config .                       # group owns every file
sudo chmod -R g+w .                          # members may write
sudo find . -type d -exec chmod g+s {} +     # new files inherit the group
sudo setfacl -R  -m g:config:rwX .           # existing files
sudo setfacl -R -d -m g:config:rwX .         # default ACL keeps new files writable
sudo chmod 600 secrets/keys.txt              # NixOS only: re-lock the sops age key
```

macOS (`/etc/nix-darwin`) — native ACLs via `chmod +a` (no setfacl):

```sh
sudo chgrp -R config .
sudo chmod -R g+w .
sudo find . -type d -exec chmod g+s {} +
sudo chmod -R +a "group:config allow read,write,execute,append,delete,delete_child,readattr,writeattr,readextattr,writeextattr,file_inherit,directory_inherit" .
```

(No `keys.txt` re-lock on macOS: the sops age key lives outside the repo
there.)

Spell every right out in that last command — do **not** shorten it to
`read,write,execute`. On a directory those three names occupy the
`list`/`add_file`/`search` bit positions, so the short form silently grants no
`delete_child` and no `add_subdirectory`: members can create a file but not
rename or delete one, nor create a subdirectory. The `chmod -R g+w` above masks
the gap until some directory loses its group-write bit (anything that creates
directories as root under umask 022), at which point every editor that saves by
renaming a temp file over the target fails and leaves the temp file behind.
Check what actually landed with `ls -lde .`; the ACE should list `delete_child`
and `add_subdirectory`. Running it recursively over files is fine — the
directory-only rights are just dropped there.

## Repair a machine bootstrapped before the corrected ACL

Such a machine carries the narrow `list,add_file,search` grant, and its `.git`
holds entries that lost their group-write bit. Run both repairs below once,
from the repo root, in this order. A machine bootstrapped from the sequence
above needs neither.

### Restore group-write on existing files

`core.sharedRepository = "group"` makes git create new files group-writable
from then on, but it does not touch what git already created. So the entries
inside `.git` that predate the setting stay unwritable by the group, which is
what makes renames and deletes fail for `nr` and plain `git`. Fix them once:

```sh
sudo chmod -R g+w .
sudo find . -type d -exec chmod g+s {} +
sudo chmod 600 secrets/keys.txt              # NixOS only: re-lock the sops age key
```

The first command sweeps the whole tree, so on NixOS the third command undoes
the group-write it just granted the age key. On NixOS the setting also covers
only the git you run yourself, not root-run git under `sudo`, so the sweep may
need repeating there.

### Replace the narrow ACL (macOS)

`chmod -R -N` clears every ACL in the tree, so confirm first that nothing but
`group:config` holds one. This prints any other entry, and nothing at all when
the tree is clean:

```sh
sudo find . -exec ls -lde {} + | grep -E '^ +[0-9]+: ' | grep -v group:config
```

Then strip the tree's ACLs and apply the corrected entry:

```sh
sudo chmod -R -N .
sudo chmod -R +a "group:config allow read,write,execute,append,delete,delete_child,readattr,writeattr,readextattr,writeextattr,file_inherit,directory_inherit" .
```

Run both. Adding the corrected entry without the `-N` leaves two entries on
every node, the new one plus the known-broken narrow one, which misleads the
next audit. Group access does not lapse between the two commands, because the
group-write mode bits restored above still grant it.

Never clear the leftover narrow entry with
`sudo chmod -R -a "group:config allow ..." .`. The `-a` flag subtracts the
rights you name instead of deleting an entry, so that command strips
`read,write,execute` and leaves group access broken. Why the strip has to come
first:
[the config-group trust model](../explanation/config-group.md#why-the-acl-repair-strips-before-it-reapplies).

## Let git open the root-owned repo (per user)

Do this before the first `nix` command you run as your own user against the
flake. Reading the flake goes through libgit2, which refuses a repository owned
by another user:

```
error: opening Git repository "/private/etc/nix-darwin": repository path '/private/etc/nix-darwin' is not owned by current user (libgit2 error code = 7)
```

The declarative git config allowlists the repo path, but no managed git config
exists yet before your first home activation. Add a temporary entry by hand:

```sh
git config --global --add safe.directory /etc/nixos                # NixOS
git config --global --add safe.directory /private/etc/nix-darwin   # macOS
```

On macOS use the `/private` spelling. Here `/etc` is a symlink to
`/private/etc`, and libgit2 does not resolve it the way the git CLI does, so an
`/etc/nix-darwin` entry never matches. Why the two differ:
[the config-group trust model](../explanation/config-group.md#why-libgit2-needs-the-private-path-on-macos).

## First home activation (per user)

Each user's very first home activation is a bootstrap: the `home-manager` CLI
and the `hr` fish function are both delivered *by* the home itself, so
neither is on PATH beforehand. Run home-manager ad hoc once:

```sh
nix run github:nix-community/home-manager -- switch -b backup --flake /etc/nixos#<user>@<host>
```

(`/etc/nix-darwin` on macOS.) Every later rebuild is just `hr` — see
[Rebuild your home](rebuild-your-home.md).

Then delete the `~/.gitconfig` that `git config --global` wrote for the
temporary `safe.directory` entry, moving anything else it holds into
`modules/programs/git/git.nix` first:

```sh
rm ~/.gitconfig
```

The managed config covers the repo path from here on, so the file is
redundant. Leaving it costs you the declarative config: git reads
`~/.gitconfig` after the managed `~/.config/git/config`, so every key it sets
silently wins. Home activation warns whenever the file exists
(`modules/programs/git/git.nix`), so a later stray `git config --global` cannot
hide for long.

## macOS account creation

macOS accounts are created imperatively in System Settings — nix-darwin never
creates them, it only records each user's home directory. Create the account
before listing the user on the host. See [Add a user](declarations/add-a-user.md).

## Karabiner-Elements first-run approval (macOS)

Karabiner's driver extension and Input Monitoring permission cannot be
automated. After the first rebuild installs the cask, approve both in System
Settings → Privacy & Security. Until they're approved, every rebuild's
activation prints a warning and launches the app to surface the prompts
(`modules/programs/karabiner/karabiner.nix`).

## What needs no manual step

- **Homebrew (macOS):** nix-homebrew installs and manages `brew` itself
  declaratively (`modules/programs/homebrew/homebrew.nix`) — never install it
  by hand.
- **`~/.config/nix-config`:** the symlink to your user folder lands at home
  activation, declaratively.
- **Group membership:** member lists are declarative (per-host on macOS,
  central on NixOS) — the only imperative part is logging out/in (or
  `newgrp config`) for a membership change to take effect.
