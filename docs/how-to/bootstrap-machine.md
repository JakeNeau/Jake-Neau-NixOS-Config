# Bootstrap a machine

Use the section for your operating system. Follow the [new-machine walkthrough](../tutorials/new-machine-walkthrough.md) first for an undeclared host.

Replace `<host>` and `<user>` with the names declared in this flake.

## NixOS

Install the system, activate its configuration, grant repository access, and activate the user's home.

### 1. Put the repository in `/etc/nixos`

Move the installer configuration aside, then use Nix to clone the root-owned repository.

```sh
# Preserve the configuration created by the NixOS installer.
sudo mv /etc/nixos /etc/nixos-installer
# Clone this flake as a root-owned checkout with Nix-provided Git.
sudo nix run nixpkgs#git -- clone https://github.com/jakeneau/Jake-Neau-NixOS-Config.git /etc/nixos
```

Skip this step when `/etc/nixos` already contains a fresh clone.

### 2. Create and authorize an age key

Generate a new private key for this machine, then use some old private key from a different machine once to grant the new key access to every existing secret.

You must retrieve the old private key from the old machine or a backup. Without one existing private key, nobody can decrypt or re-key the secrets.

```sh
# Copy the old private key temporarily from its mounted backup or transfer location.
sudo cp /path/to/old-private-key.txt /tmp/old-age-key.txt
# Restrict the temporary old key to root.
sudo chmod 600 /tmp/old-age-key.txt
# Generate the new private key where this NixOS configuration expects it.
sudo nix shell nixpkgs#age -c age-keygen -o /etc/nixos/secrets/keys.txt
# Restrict the new private key to root.
sudo chmod 600 /etc/nixos/secrets/keys.txt
# Print the new public recipient that must be added to .sops.yaml.
sudo nix shell nixpkgs#age -c age-keygen -y /etc/nixos/secrets/keys.txt
# Open the SOPS recipient configuration with a Nix-provided editor.
sudo nix run nixpkgs#vim -- /etc/nixos/.sops.yaml
```

Add the printed `age1...` recipient beside the existing recipient and reference both keys in the creation rule:

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

Authorize and test the new key from the repository root:

```sh
# Enter the repository so SOPS finds .sops.yaml.
cd /etc/nixos
# Use the old key to encrypt the secrets data key for every configured recipient.
sudo SOPS_AGE_KEY_FILE=/tmp/old-age-key.txt nix run nixpkgs#sops -- updatekeys secrets/secrets.yaml
# Prove that the new private key can decrypt every secret without saving plaintext.
sudo SOPS_AGE_KEY_FILE=/etc/nixos/secrets/keys.txt nix run nixpkgs#sops -- decrypt secrets/secrets.yaml >/dev/null
# Remove the temporary copy of the old private key.
sudo rm -f /tmp/old-age-key.txt
```

After bootstrap, commit `.sops.yaml` and `secrets/secrets.yaml`. Both files contain only public or encrypted data.

### 3. Check and build the system

Evaluate the flake and dry-build the host before activating it.

```sh
# Evaluate every flake check supported by this machine.
sudo nix flake check /etc/nixos
# Build the selected NixOS system without activating it or creating a result link.
sudo nix build '/etc/nixos#nixosConfigurations.<host>.config.system.build.toplevel' --no-link
```

### 4. Activate the system

Switch to the built configuration so NixOS creates the declared users and `config` group.

```sh
# Activate the selected host configuration.
sudo nixos-rebuild switch --flake /etc/nixos#<host>
```

### 5. Grant the `config` group repository access

Set group ownership, writable modes, inheritance, and ACLs so declared members can edit without `sudo`.

```sh
# Enter the repository before applying relative permission commands.
cd /etc/nixos
# Assign the repository tree to the config group.
sudo chgrp -R config .
# Let config group members modify existing entries.
sudo chmod -R g+w .
# Make new entries inherit the config group.
sudo find . -type d -exec chmod g+s {} +
# Grant the config group access to every existing entry.
sudo nix shell nixpkgs#acl -c setfacl -R -m g:config:rwX .
# Make new entries inherit the config group ACL.
sudo nix shell nixpkgs#acl -c setfacl -R -d -m g:config:rwX .
# Remove group access from the private age key.
sudo chmod 600 secrets/keys.txt
```

### 6. Refresh group membership

Log out and back in so the new login session includes the `config` group.

### 7. Allow Nix to read the root-owned repository

Add the repository to this user's temporary safety list with Nix-provided Git.

```sh
# Allow libgit2 to read this root-owned repository.
nix run nixpkgs#git -- config --global --add safe.directory /etc/nixos
```

### 8. Activate the user's home

Run Home Manager through Nix once to install the managed home and the later `hr` command.

```sh
# Activate the selected standalone Home Manager configuration.
nix run github:nix-community/home-manager -- switch -b backup --flake /etc/nixos#<user>@<host>
```

### 9. Remove the temporary Git configuration

Delete the bootstrap file because Home Manager now supplies the Git settings.

```sh
# Remove the temporary safety entry and any duplicate unmanaged Git settings.
rm -f ~/.gitconfig
```

Future home rebuilds use `hr`.

## macOS

Install Nix, activate nix-darwin, grant repository access, and activate the user's home.

### 1. Install Nix

Install [Nix](https://nixos.org/download/) in multi-user mode with flakes enabled.

### 2. Put the repository in `/etc/nix-darwin`

Clone with Nix-provided Git and `sudo` to keep the checkout owned by root.

```sh
# Clone this flake as a root-owned checkout with Nix-provided Git.
sudo nix run nixpkgs#git -- clone https://github.com/jakeneau/Jake-Neau-NixOS-Config.git /etc/nix-darwin
```

Skip this step when `/etc/nix-darwin` already contains a fresh clone.

### 3. Check and build the system

Evaluate the flake and dry-build the host before activating it.

```sh
# Evaluate every flake check supported by this machine.
sudo nix flake check /etc/nix-darwin
# Build the selected nix-darwin system without activating it or creating a result link.
sudo nix build '/etc/nix-darwin#darwinConfigurations.<host>.system' --no-link
```

### 4. Activate the system

Run nix-darwin through Nix once so it installs `darwin-rebuild` and creates the `config` group.

```sh
# Bootstrap darwin-rebuild and activate the selected host configuration.
sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake /etc/nix-darwin#<host>
```

### 5. Grant the `config` group repository access

Set group ownership, writable modes, inheritance, and complete macOS ACL rights.

```sh
# Enter the repository before applying relative permission commands.
cd /etc/nix-darwin
# Assign the repository tree to the config group.
sudo chgrp -R config .
# Let config group members modify existing entries.
sudo chmod -R g+w .
# Make new entries inherit the config group.
sudo find . -type d -exec chmod g+s {} +
# Grant complete create, rename, delete, and inheritance rights to the config group.
sudo chmod -R +a "group:config allow read,write,execute,append,delete,delete_child,readattr,writeattr,readextattr,writeextattr,file_inherit,directory_inherit" .
```

### 6. Refresh group membership

Log out and back in so the new login session includes the `config` group.

### 7. Allow Nix to read the root-owned repository

Add the real macOS path to this user's temporary safety list with Nix-provided Git.

```sh
# Allow libgit2 to read the root-owned repository through its real macOS path.
nix run nixpkgs#git -- config --global --add safe.directory /private/etc/nix-darwin
```

### 8. Activate the user's home

Run Home Manager through Nix once to install the managed home and the later `hr` command.

```sh
# Activate the selected standalone Home Manager configuration.
nix run github:nix-community/home-manager -- switch -b backup --flake /etc/nix-darwin#<user>@<host>
```

### 9. Remove the temporary Git configuration

Delete the bootstrap file because Home Manager now supplies the Git settings.

```sh
# Remove the temporary safety entry and any duplicate unmanaged Git settings.
rm -f ~/.gitconfig
```

Future home rebuilds use `hr`.

### 10. Approve Karabiner-Elements

Approve Karabiner's driver and Input Monitoring access in **System Settings → Privacy & Security**.

These approvals allow Karabiner-Elements to receive keys and use its virtual keyboard driver.
