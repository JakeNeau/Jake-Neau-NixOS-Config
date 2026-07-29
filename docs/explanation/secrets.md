# The secrets flow

Why secrets are managed with sops-nix + age, and how the design keeps a
public repo safe. The recipe: [Add a secret](../how-to/declarations/add-a-secret.md).

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

## Scope: editable everywhere, consumed only on NixOS

Both halves live in the `secrets-management` program
(`modules/programs/secrets-management/secrets-management.nix`). The
tooling half is a plain per-user declaration — `sops` and `age` install
into the home of any user who lists `secrets-management` in their
`flake.users.<u>.programs`, on both platforms. Both users do today, so a
secret can be edited from any machine, once that user's home is
activated.

Consumption is narrower. The decryption wiring is the hand-written
`flake.modules.nixos.secrets-management` aspect (hence the declaration's
`handWritten = ["nixos"]`), imported by `role-default`'s nixos imports,
and no darwin equivalent exists. The macs carry no declared secrets; the
fact is worth knowing before reaching for a secret in darwin or
home-manager config, where the flow simply isn't plumbed.

`.sops.yaml` and `secrets/` stay at the repo root, not beside the
program: the `sops` CLI discovers `.sops.yaml` by walking up from the
working directory, and its `creation_rules` match on
`path_regex: secrets/secrets.yaml$`.
