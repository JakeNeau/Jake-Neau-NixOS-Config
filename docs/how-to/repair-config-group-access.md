# Repair config-group repository access

Use this procedure only when an older bootstrap left repository files unwritable or created a narrow macOS ACL.

## NixOS

Restore group-write and inheritance permissions, then protect the sops key again.

```sh
cd /etc/nixos
sudo chmod -R g+w .
sudo find . -type d -exec chmod g+s {} +
sudo chmod 600 secrets/keys.txt
```

`chmod g+w` repairs existing files, `chmod g+s` restores group inheritance, and the final command protects the private key.

## macOS

Confirm that only `group:config` has ACL entries, then replace all narrow entries with one complete entry.

### 1. Check existing ACL identities

Print ACL entries that belong to an identity other than `group:config`.

```sh
cd /etc/nix-darwin
sudo find . -exec ls -lde {} + | grep -E '^ +[0-9]+: ' | grep -v group:config
```

Stop if this command prints any output because the next step removes every ACL.

### 2. Restore writable modes and inheritance

Repair existing group access before replacing ACLs.

```sh
sudo chmod -R g+w .
sudo find . -type d -exec chmod g+s {} +
```

The first command restores writes. The second makes new entries inherit the `config` group.

### 3. Replace the ACLs

Remove every old ACL, then add one complete `config` group entry.

```sh
sudo chmod -R -N .
sudo chmod -R +a "group:config allow read,write,execute,append,delete,delete_child,readattr,writeattr,readextattr,writeextattr,file_inherit,directory_inherit" .
```

The first command removes stale entries. The second restores create, rename, delete, and inheritance rights.

Do not use `chmod -a` for this repair because it subtracts rights instead of deleting an ACL entry.
