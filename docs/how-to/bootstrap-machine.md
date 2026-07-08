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
[edit secrets](add-a-secret.md).

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
sudo chmod 600 secrets/keys.txt              # re-lock the sops age key (Linux only)
```

macOS (`/etc/nix-darwin`) — native ACLs via `chmod +a` (no setfacl):

```sh
sudo chgrp -R config .
sudo chmod -R g+w .
sudo find . -type d -exec chmod g+s {} +
sudo chmod -R +a "group:config allow read,write,execute,file_inherit,directory_inherit" .
```

(No `keys.txt` re-lock on macOS: the sops age key lives outside the repo
there.)

## First home activation (per user)

Each user's very first home activation is a bootstrap: the `home-manager` CLI
and the `hr` fish function are both delivered *by* the home itself, so
neither is on PATH beforehand. Run home-manager ad hoc once:

```sh
nix run github:nix-community/home-manager -- switch -b backup --flake /etc/nixos#<user>@<host>
```

(`/etc/nix-darwin` on macOS.) Every later rebuild is just `hr` — see
[Rebuild your home](rebuild-your-home.md).

## macOS account creation

macOS accounts are created imperatively in System Settings — nix-darwin never
creates them, it only records each user's home directory. Create the account
before listing the user on the host. See [Add a user](add-a-user.md).

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
