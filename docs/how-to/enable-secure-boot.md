# Enable Secure Boot on Redwood

Redwood uses Lanzaboote to sign its systemd-boot loader and NixOS boot
artifacts. The signing keys remain outside the Nix store in `/var/lib/sbctl`.
The firmware must trust those keys before it can enforce Secure Boot.

Complete the migration in stages. Keep Secure Boot disabled until Redwood has
booted successfully through Lanzaboote once.

## 1. Check the firmware state

Run:

```fish
bootctl status
```

The initial migration requires UEFI and Secure Boot Setup Mode. Redwood's
ASRock firmware reports this state as `Secure Boot: disabled (setup)`.

Check that the forbidden-signature database exists:

```fish
find /sys/firmware/efi/efivars -maxdepth 1 -name 'dbx-*' -printf '%s bytes\n'
```

If the command produces no output, restore only the forbidden signatures in
the firmware:

1. Open **Security → Secure Boot**.
2. Set **Secure Boot Mode** to **Custom**.
3. Open **Key Management**.
4. Open **Forbidden Signatures**.
5. Select **Enroll Factory Defaults**.

Do not select **Clear Secure Boot Keys**. That action clears every Secure Boot
database, including `dbx`.

## 2. Generate the signing keys

Enter a temporary shell containing `sbctl`, then create the keys as root:

```fish
nix shell nixpkgs#sbctl
sudo (type -p sbctl) create-keys
exit
```

Back up `/var/lib/sbctl` to encrypted offline storage. Never add that directory
or its private keys to this repository.

## 3. Install Lanzaboote

Run the normal Redwood `nr` rebuild flow. The activation installs signed boot
artifacts on the EFI System Partition.

Before enabling Secure Boot, verify the installed artifacts:

```fish
sudo sbctl verify
bootctl status
```

Lanzaboote must sign the systemd-boot executable, fallback executable, and
Lanzaboote generation images. Old GRUB files and standalone kernel files may
remain unsigned.

Reboot once with Secure Boot still disabled. Confirm that Redwood starts
through systemd-boot before continuing.

## 4. Enroll the keys

Redwood also boots Windows and may use Microsoft-signed option ROMs. Enroll the
Microsoft certificates with the local keys:

```fish
sudo sbctl enroll-keys --microsoft
```

Reboot, then verify enforcement:

```fish
bootctl status
sudo sbctl status
```

`bootctl status` must report `Secure Boot: enabled (user)`. Test Windows through
the firmware boot selector because its boot manager resides on another EFI
partition.

## Recovery

If the firmware rejects every NixOS entry, disable Secure Boot in the firmware.
Boot the unsigned fallback, repair the configuration, and enroll the keys
again. Keep the old GRUB files until Lanzaboote and Windows have both booted
successfully.

The upstream procedures are [Prepare Your
System](https://nix-community.github.io/lanzaboote/getting-started/prepare-your-system.html)
and [Enable Secure
Boot](https://nix-community.github.io/lanzaboote/getting-started/enable-secure-boot.html).
