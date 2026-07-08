# The secrets flow

Why secrets are managed with sops-nix + age, and how the design keeps a
public repo safe. The recipe: [Add a secret](../how-to/add-a-secret.md).

## The constraint: a public, declarative repo

This repo is pushed to public GitHub on every rebuild, and the design
principles demand everything be declared in it. Those pull in opposite
directions for secrets: they must live in the tree to be declarative, and
must never be readable there. sops-nix resolves the tension by committing
secrets *encrypted* — `secrets/secrets.yaml` is in git, ciphertext only —
and decrypting at activation on the machine that owns the key.

## The trust anchor

Decryption needs the age private key, which is the one thing that never
enters git: `secrets/keys.txt` on Linux (inside the repo path but
untracked and re-locked to mode 600 by the bootstrap ACL sequence), a path
outside the repo on macOS. `.sops.yaml` pins the corresponding public
keys, so `sops` encrypts new secrets to every machine that should read
them. A machine without the key can still build — it just can't produce
the plaintext.

## Consumption by path, never by value

NixOS features never read a secret's *value*: anything interpolated into
Nix would land in the world-readable store. Instead sops-nix decrypts each
secret to `/run/secrets/<name>` at activation and features reference the
*path*. Secrets needed before user creation (the hashed login password)
are flagged `neededForUsers`.

## Scope: NixOS only

Only the NixOS side consumes secrets today — the sops aspect is
`flake.modules.nixos.secrets` (`modules/nix/tools/sops/sops.nix`), wired
into `role-default`'s nixos imports, and no darwin secrets module exists.
The macs carry no declared secrets; the fact is worth knowing before
reaching for a secret in darwin or home-manager config, where the flow
simply isn't plumbed.
