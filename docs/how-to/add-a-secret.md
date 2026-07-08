# Add a secret

Secrets are managed with sops-nix + age. Plaintext never lives in `.nix`
files or in git: encrypted values go in `secrets/secrets.yaml`, and NixOS
hosts decrypt them at activation with the age key at
`/etc/nixos/secrets/keys.txt` (wired in `modules/nix/tools/sops/sops.nix`).
Only NixOS consumes secrets today — no darwin secrets module exists.

## 1. Have the age key available

Editing `secrets/secrets.yaml` requires the age *private* key (sops must
decrypt the file to re-encrypt it). The matching recipient is pinned in
`.sops.yaml` at the repo root.

- **Linux hosts:** the key is already at `/etc/nixos/secrets/keys.txt`
  (root-only). Point sops at it for the edit.
- **macOS:** the key lives outside the repo; put it at sops' default lookup
  (`~/Library/Application Support/sops/age/keys.txt`) or point
  `SOPS_AGE_KEY_FILE` at wherever you keep it.

## 2. Edit the secrets file

The `sops` CLI ships on every host (the `cli` aspect). From the repo root:

```sh
sudo SOPS_AGE_KEY_FILE=/etc/nixos/secrets/keys.txt sops secrets/secrets.yaml   # Linux
sops secrets/secrets.yaml                                                      # macOS (key in the default location)
```

sops opens the decrypted YAML in your editor; add your key/value, save, and
it re-encrypts against the recipients in `.sops.yaml`.

## 3. Declare and consume it

Declare the secret so sops-nix decrypts it, in
`modules/nix/tools/sops/sops.nix` (or in the feature that uses it):

```nix
sops.secrets.mySecret = {};
# neededForUsers = true; only for secrets read during user creation,
# e.g. secrets.hashedPasswordJakeNeau
```

Then read it by *path*, never by value — the decrypted file lands under
`/run/secrets`:

```nix
users.users.jakeneau.hashedPasswordFile = config.sops.secrets.hashedPasswordJakeNeau.path;
```

## 4. Verify

```sh
git add <any-new-files>
nix flake check
nix build .#nixosConfigurations.<host>.config.system.build.toplevel --no-link
```

Never commit `secrets/keys.txt`; committing `secrets/secrets.yaml` (the
encrypted file) is the whole point.
