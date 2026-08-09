# Bootstrap a machine

Use the section for your operating system. The NixOS path starts from installation media. The macOS path starts from Setup Assistant.

Before you begin, confirm these requirements:

- The machine has internet access.
- You have an administrator account with `sudo` access.
- `<host>` and `<user>` already exist in this flake.
- The account name matches the declared `<user>` exactly.
- A NixOS machine can access one authorized age private key.

Follow the [new-machine walkthrough](../tutorials/new-machine-walkthrough.md) first when the host is not declared.

Replace every `<host>`, `<user>`, path, and email placeholder before running a command. Do not type the angle brackets.

Commands before the first system activation enable `nix-command` and flakes explicitly. The activated configuration enables them permanently.

## NixOS

### 1. Install NixOS

On another computer, download the [NixOS graphical ISO](https://nixos.org/download/). Write it to a USB drive with an image-writing tool.

Boot the target machine from that USB drive. Complete the graphical installer, remove the USB drive, and reboot into the installed system.

Keep the installer-generated `/etc/nixos` directory. It contains the hardware configuration for this machine.

Confirm that Nix and the network work:

```sh
whoami
nix --version
getent hosts github.com
```

Stop and restore network access if the second command prints nothing.

### 2. Put the repository in `/etc/nixos`

Move `/etc/nixos` aside. Then use Nix-provided Git to clone the root-owned repository.

```sh
# Preserve the installer configuration and hardware data.
sudo mv /etc/nixos /etc/nixos-installer
# Clone without requiring Git to be installed globally.
sudo nix --extra-experimental-features 'nix-command flakes' run nixpkgs#git -- \
  clone https://github.com/jakeneau/Jake-Neau-NixOS-Config.git /etc/nixos
```

Skip this step when `/etc/nixos` already contains a fresh clone.

For a new host, keep `/etc/nixos-installer/hardware-configuration.nix` available while following the [new-machine walkthrough](../tutorials/new-machine-walkthrough.md).

### 3. Create and authorize an age key

Generate a private key for this machine. Use an authorized private key from another machine or backup once to re-key the secrets.

Without one authorized private key, nobody can decrypt or re-key the existing secrets.

```sh
# Copy the old key from its mounted backup or transfer location.
sudo cp /path/to/old-private-key.txt /tmp/old-age-key.txt
sudo chmod 600 /tmp/old-age-key.txt
# Generate the new machine key in the path used by this configuration.
sudo nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#age -c \
  age-keygen -o /etc/nixos/secrets/keys.txt
sudo chmod 600 /etc/nixos/secrets/keys.txt
# Print the new public recipient.
sudo nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#age -c \
  age-keygen -y /etc/nixos/secrets/keys.txt
# Edit the recipient configuration with a temporary editor.
sudo nix --extra-experimental-features 'nix-command flakes' run nixpkgs#vim -- \
  /etc/nixos/.sops.yaml
```

Add the printed `age1...` recipient beside the existing recipient. Reference both keys in the creation rule:

```yaml
keys:
  - &primary age18euptmpz2v6rmxsr475zr3p3d4sfnkcp5ktcl2ctms7td2h7kcuqxxgzl2
  - &new-machine <new-age1-public-recipient>
creation_rules:
  - path_regex: secrets/secrets.yaml$
    key_groups:
      - age:
          - *primary
          - *new-machine
```

Authorize and test the new key:

```sh
cd /etc/nixos
# Encrypt the secrets data key for every configured recipient.
sudo env SOPS_AGE_KEY_FILE=/tmp/old-age-key.txt \
  nix --extra-experimental-features 'nix-command flakes' run nixpkgs#sops -- \
  updatekeys secrets/secrets.yaml
# Prove that the new key can decrypt the file without saving plaintext.
sudo env SOPS_AGE_KEY_FILE=/etc/nixos/secrets/keys.txt \
  nix --extra-experimental-features 'nix-command flakes' run nixpkgs#sops -- \
  decrypt secrets/secrets.yaml >/dev/null
sudo rm -f /tmp/old-age-key.txt
```

The repository ignores `secrets/keys.txt`. Never add that private key to Git.

Commit `.sops.yaml` and `secrets/secrets.yaml` after you configure GitHub access. Both files contain only public or encrypted data.

### 4. Check and build the system

Evaluate the flake and dry-build the declared host:

```sh
sudo nix --extra-experimental-features 'nix-command flakes' flake check /etc/nixos
sudo nix --extra-experimental-features 'nix-command flakes' build \
  '/etc/nixos#nixosConfigurations.<host>.config.system.build.toplevel' --no-link
```

Fix every error before activation.

### 5. Activate the system

Activate the host so NixOS creates the declared users and `config` group:

```sh
sudo env NIX_CONFIG='experimental-features = nix-command flakes' \
  nixos-rebuild switch --flake /etc/nixos#<host>
```

### 6. Grant repository access

Set ownership, writable modes, inheritance, and ACLs for the `config` group:

```sh
cd /etc/nixos
sudo chgrp -R config .
sudo chmod -R g+w .
sudo find . -type d -exec chmod g+s {} +
sudo nix shell nixpkgs#acl -c setfacl -R -m g:config:rwX .
sudo nix shell nixpkgs#acl -c setfacl -R -d -m g:config:rwX .
# Remove group access from the private age key.
sudo chmod 600 secrets/keys.txt
```

Log out and back in so the current session receives `config` group membership.

Confirm the membership before continuing:

```sh
groups | grep -w config
```

### 7. Allow Nix to read the repository

The checkout is root-owned. Add its path to this user's temporary Git safety configuration:

```sh
nix run nixpkgs#git -- config --global --add safe.directory /etc/nixos
```

### 8. Activate the user's home

Run Home Manager through Nix once. This activation installs the managed `home-manager`, `git`, `hr`, and `nr` commands.

```sh
nix run github:nix-community/home-manager -- switch -b backup \
  --flake '/etc/nixos#"<user>@<host>"'
```

### 9. Remove the temporary Git configuration

The managed Git configuration now contains the safe repository path. Remove the temporary file:

```sh
rm -f ~/.gitconfig
```

Future home rebuilds use `hr`.

Continue with [Configure GitHub push access](#configure-github-push-access) before running `nr`.

## macOS

### 1. Prepare macOS

If the disk has no operating system, [reinstall macOS from Recovery](https://support.apple.com/guide/mac-help/reinstall-macos-mchlp1599/mac).

Finish Setup Assistant and create an administrator account. Its short account name must match the declared `<user>`.

Open Terminal and confirm internet access:

```sh
whoami
dscacheutil -q host -a name github.com
```

Stop and restore network access if this command prints nothing.

### 2. Install Nix

Install Nix in the recommended multi-user mode:

```sh
curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install | \
  sh -s -- --daemon
```

Close Terminal after the installer completes. Open a new Terminal so its shell can find Nix.

Confirm the installation:

```sh
nix --version
```

### 3. Put the repository in `/etc/nix-darwin`

Use Nix-provided Git to clone the root-owned repository:

```sh
sudo nix --extra-experimental-features 'nix-command flakes' run nixpkgs#git -- \
  clone https://github.com/jakeneau/Jake-Neau-NixOS-Config.git /etc/nix-darwin
```

Skip this step when `/etc/nix-darwin` already contains a fresh clone.

### 4. Check and build the system

Evaluate the flake and dry-build the declared host:

```sh
sudo nix --extra-experimental-features 'nix-command flakes' flake check /etc/nix-darwin
sudo nix --extra-experimental-features 'nix-command flakes' build \
  '/etc/nix-darwin#darwinConfigurations.<host>.system' --no-link
```

Fix every error before activation.

### 5. Activate the system

Run nix-darwin through Nix once. This command installs `darwin-rebuild` and creates the `config` group:

```sh
sudo nix --extra-experimental-features 'nix-command flakes' run \
  nix-darwin/master#darwin-rebuild -- \
  switch --flake /etc/nix-darwin#<host>
```

### 6. Grant repository access

Set ownership, writable modes, inheritance, and complete macOS ACL rights:

```sh
cd /etc/nix-darwin
sudo chgrp -R config .
sudo chmod -R g+w .
sudo find . -type d -exec chmod g+s {} +
sudo chmod -R +a \
  "group:config allow read,write,execute,append,delete,delete_child,readattr,writeattr,readextattr,writeextattr,file_inherit,directory_inherit" .
```

Log out and back in so the current session receives `config` group membership.

Confirm the membership before continuing:

```sh
groups | grep -w config
```

### 7. Allow Nix to read the repository

The checkout is root-owned. Add its real path to this user's temporary Git safety configuration:

```sh
nix run nixpkgs#git -- config --global --add safe.directory /private/etc/nix-darwin
```

libgit2 requires the `/private` spelling because it resolves the macOS path differently from Git.

### 8. Activate the user's home

Run Home Manager through Nix once. This activation installs the managed `home-manager`, `git`, `hr`, and `nr` commands.

```sh
nix run github:nix-community/home-manager -- switch -b backup \
  --flake '/etc/nix-darwin#"<user>@<host>"'
```

### 9. Remove the temporary Git configuration

The managed Git configuration now contains the safe repository path. Remove the temporary file:

```sh
rm -f ~/.gitconfig
```

Future home rebuilds use `hr`.

### 10. Approve Karabiner-Elements

Approve Karabiner's driver and Input Monitoring access in **System Settings → Privacy & Security**.

These approvals allow Karabiner-Elements to receive keys and use its virtual keyboard driver.

Continue with [Configure GitHub push access](#configure-github-push-access) before running `nr`.

## Configure GitHub push access

The public HTTPS clone needs no credentials. The `nr` command does need authenticated push access.

Reuse an existing GitHub SSH private key from a secure backup when possible:

```sh
mkdir -p ~/.ssh
chmod 700 ~/.ssh
install -m 600 /path/to/backed-up-id_ed25519 ~/.ssh/id_ed25519
nix shell nixpkgs#openssh -c ssh-keygen -y -f ~/.ssh/id_ed25519 \
  >~/.ssh/id_ed25519.pub
chmod 644 ~/.ssh/id_ed25519.pub
```

Otherwise, create a key:

```sh
mkdir -p ~/.ssh
chmod 700 ~/.ssh
nix shell nixpkgs#openssh -c ssh-keygen -t ed25519 \
  -f ~/.ssh/id_ed25519 -C '<GitHub email>'
chmod 600 ~/.ssh/id_ed25519
```

For a new key, add `~/.ssh/id_ed25519.pub` to **GitHub → Settings → SSH and GPG keys**. A restored key should already appear there.

Load the key into the current session.

On NixOS, start an agent in the managed Fish shell:

```fish
eval (nix shell nixpkgs#openssh -c ssh-agent -c)
nix shell nixpkgs#openssh -c ssh-add ~/.ssh/id_ed25519
```

Load the key again after a login when the new session has no SSH agent identity.

On macOS:

```sh
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
```

Before each `nr` run, confirm that the current agent holds the key:

```sh
nix shell nixpkgs#openssh -c ssh-add -l
```

Reload the key with the platform command above if this check reports no identities.

Change the checkout to the SSH remote:

```sh
# Use /etc/nix-darwin on macOS.
nix run nixpkgs#git -- -C /etc/nixos remote set-url origin \
  git@github.com:JakeNeau/Jake-Neau-NixOS-Config.git
```

The `nr` command runs Git through `sudo`. Prepare root's SSH host-key file and test that exact authentication path:

```sh
sudo -H sh -c 'mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"'
sudo -H env SSH_AUTH_SOCK="$SSH_AUTH_SOCK" \
  nix shell nixpkgs#openssh -c ssh -T git@github.com
```

On the first connection, verify GitHub's host fingerprint before accepting it.

GitHub confirms the SSH key. The command returns status 1 because GitHub provides no shell.

Commit the bootstrap changes with the normal verified flow:

```sh
nr "Bootstrap <host>"
```
