# Add a secret

Secrets are managed with sops-nix + age. Plaintext never lives in `.nix`
files or in git: encrypted values go in `secrets/secrets.yaml`, and NixOS
hosts decrypt them at activation with the age key at
`/etc/nixos/secrets/keys.txt` (wired in
`modules/programs/secrets-management/secrets-management.nix`).
Only NixOS consumes secrets today — no darwin secrets module exists.

## 1. Have the age key available

Editing `secrets/secrets.yaml` requires an age *private* key that matches one
authorized recipient. SOPS must decrypt the file before re-encrypting it.
`.sops.yaml` lists the authorized public recipients.

- **Linux hosts:** the key is already at `/etc/nixos/secrets/keys.txt`
  (root-only). Point sops at it for the edit.
- **macOS:** the key lives outside the repo; put it at sops' default lookup
  (`~/Library/Application Support/sops/age/keys.txt`) or point
  `SOPS_AGE_KEY_FILE` at wherever you keep it.

## 2. Edit the secrets file

The `sops` and `age` CLIs come from the `secrets-management` program,
declared today by both users (`modules/users/*/`), so they arrive with a
user's home activation — not with the system switch. From the repo root:

```sh
sudo SOPS_AGE_KEY_FILE=/etc/nixos/secrets/keys.txt sops secrets/secrets.yaml   # Linux
sops secrets/secrets.yaml                                                      # macOS (key in the default location)
```

The Linux form works because sudo here defines no `secure_path` and so
inherits your PATH. A root login shell (`sudo -i`, single-user mode) has
neither binary; run the command as yourself, as above.

sops opens the decrypted YAML in your editor; add your key/value, save, and
it re-encrypts against the recipients in `.sops.yaml`.

## 3. Declare and consume it

Declare the secret so sops-nix decrypts it, in
`modules/programs/secrets-management/secrets-management.nix` (or in the
feature that uses it):

```nix
# add neededForUsers = true; inside the braces only for secrets read
# during user creation, e.g. secrets.hashedPasswordJakeNeau
sops.secrets.mySecret = {};
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
