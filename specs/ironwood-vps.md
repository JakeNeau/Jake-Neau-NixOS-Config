## Spec

Create `ironwood` as a headless Hetzner Cloud CPX11 host in this flake. The host must target `x86_64-linux`, use the existing `jakeneau` account, and expose only SSH administration.

Install Ironwood through Hetzner's Linux rescue system with `nixos-anywhere` and Disko. Add Disko as a flake input and publish its NixOS module through the repository's aspect system. Define a Disko layout for `/dev/sda` that supports Hetzner's legacy boot environment and UEFI, with an ext4 root filesystem. The installation command must build on the local machine and must identify its disk-wiping effect before execution.

Add a reusable NixOS `role-server` aspect. The role must import only the minimal system facilities required for a managed server. It must not import desktop, audio, printing, discovery, or wireless networking features. Ironwood must use the QEMU guest profile, DHCP for IPv4, UTC, and the NixOS state version appropriate at first installation.

Extend `hostConstants.graphicsType` with a headless value instead of assigning Ironwood a false physical GPU vendor. Set Ironwood's host name to `ironwood` and its graphics type to that headless value.

Configure SSH with these controls:

- Authorize the existing `~/.ssh/id_ed25519.pub` key for `jakeneau`.
- Disable root login.
- Disable password and keyboard-interactive authentication.
- Allow only `jakeneau` to log in.
- Disable agent, TCP, X11, stream-local, and tunnel forwarding.
- Reduce the login grace period and maximum authentication attempts.
- Keep SSH on TCP port 22.

Enable the NixOS firewall and open only TCP port 22. Enable Fail2ban for SSH. Keep password-protected `sudo` for the administrator account. Do not enable full-disk encryption.

Generate a dedicated age key pair for Ironwood. Add only its public recipient to `.sops.yaml`, re-key the encrypted secrets file, and keep the private identity outside Git. Supply the private identity during installation with `nixos-anywhere --extra-files` so SOPS can provide the existing administrator password hash on first activation.

Configure a Hetzner Cloud firewall before installation. Permit inbound TCP port 22 from all addresses because the administrator's source address changes. Permit ICMP for network operation and diagnostics. Deny every other unsolicited inbound connection. Keep outbound traffic allowed.

After installation, verify the final SSH host fingerprint through the Hetzner console before accepting it locally. Then log in as `jakeneau` with the authorized key. Confirm that root and password logins fail. Confirm that `sudo` requires the managed password. Confirm that Fail2ban runs and both firewalls enforce the intended policy.

Document the Hetzner-specific bootstrap procedure and link it from the existing machine bootstrap documentation. Include rescue activation, destructive-operation boundaries, age-key transfer, installation, host-key verification, repository setup, and recovery guidance.

Format all Nix changes with `nix fmt`. Regenerate `flake.nix` through `nix run .#write-flake` instead of editing it. Stage new module files before flake evaluation. Validate with `nix flake check`, the Ironwood system dry-build using `--no-link`, and the `jakeneau@ironwood` home activation-package dry-build. Do not run a system switch, remote installation, destructive disk command, commit, or push during implementation.

The work is complete when the repository validations pass and the documented procedure is ready for the user to execute. The later remote installation remains a separate, explicit approval step because it destroys the VPS disk.

## Plan

Implement Ironwood in seven bounded stages. Repository implementation ends before any remote or destructive action.

### 1. Add Disko integration

- Create `modules/nix/tools/disko/disko.nix`.
- Declare `inputs.disko` with `nixpkgs` following this flake.
- Publish `flake.modules.nixos.disko`.
- Import `inputs.disko.nixosModules.disko` through that aspect.
- Regenerate `flake.nix` and update only Disko's lock graph.

### 2. Add the server role

Create `modules/host-config/roles/server/server.nix`.

The NixOS aspect will compose:

- `role-minimal`
- `host-constants`
- `secrets-management`
- `config-group`
- `git`
- `fish`
- the generic network aspect

The Home Manager aspect will compose `role-default` and `fish`. This gives the server the managed Git and rebuild workflow without desktop packages.

The NixOS role will also enforce:

- OpenSSH with public-key authentication only
- `PermitRootLogin = "no"`
- `AuthenticationMethods = "publickey"`
- disabled password and keyboard-interactive authentication
- disabled agent, TCP, X11, stream-local, and tunnel forwarding
- a 30-second login grace period
- three authentication attempts
- an explicit firewall rule for TCP port 22
- `services.openssh.openFirewall = false`
- Fail2ban with incremental bans
- password-required `sudo`
- `security.sudo.execWheelOnly = true`

Host-specific allowed users and keys will remain outside the reusable role.

### 3. Add Ironwood

Create:

- `modules/hosts/ironwood/configuration.nix`
- `modules/hosts/ironwood/hardware.nix`

The declaration will target `x86_64-linux`, list `jakeneau`, use the `role-server` home baseline, and avoid global desktop programs.

The host aspect will:

- import `role-server`, Disko, and the Numtide cache
- set `hostName = "ironwood"`
- set `graphicsType = "none"`
- set `system.stateVersion = "26.11"`
- authorize the selected Ed25519 public key
- restrict SSH to `jakeneau`
- use UTC

The hardware aspect will:

- import the NixOS QEMU guest profile
- use IPv4 DHCP
- define `/dev/sda` through Disko
- create an EF02 BIOS partition
- create a 512 MiB EFI system partition
- use the remaining space for ext4 root
- configure GRUB for both BIOS and removable-path UEFI boot

### 4. Model headless hosts

Extend `hostConstants.graphicsType` with `"none"`.

Update the host-facts and graphics documentation. Explain that `"none"` activates no vendor module and avoids false GPU declarations.

### 5. Provision the age recipient safely

- Ignore `secrets/ironwood-keys.txt` in `.gitignore`.
- Generate that private identity with mode `0600`.
- Add only its public recipient to `.sops.yaml`.
- Re-key `secrets/secrets.yaml` with the existing primary identity.
- Verify both the existing and Ironwood identities can decrypt the result.
- Stop if generation, re-keying, or either decryption check fails.

The bootstrap guide will stage the Ironwood identity as `/etc/nixos/secrets/keys.txt` under a temporary `--extra-files` tree. The procedure must delete the temporary tree after `nixos-anywhere` exits.

### 6. Document bootstrap and recovery

Create:

- `docs/how-to/bootstrap-hetzner-vps.md`
- `docs/explanation/server-security.md`

Update:

- `docs/how-to/bootstrap-machine.md`
- `docs/tutorials/new-machine-walkthrough.md`
- `docs/reference/feature-index.md`
- `docs/explanation/host-facts.md`
- `docs/explanation/graphics-self-activation.md`
- `TODO.md`

The procedure will cover:

- Hetzner firewall rules for SSH and ICMP
- rescue activation with the selected SSH key
- verification that the target disk is `/dev/sda`
- the destructive boundary before `nixos-anywhere`
- age-key staging
- local building and remote installation
- final host-key verification through the Hetzner console
- repository cloning and permission setup
- login, `sudo`, firewall, and Fail2ban checks
- rescue-based recovery

The existing Tailscale TODO will add Ironwood to its future mesh scope.

### 7. Validate without activation

- Format all Nix files.
- Stage new modules before flake evaluation.
- Confirm the evaluated SSH policy and firewall expose only port 22.
- Confirm the Disko layout contains BIOS, EFI, and root partitions.
- Run `nix flake check`.
- Dry-build Ironwood's system with `--no-link`.
- Dry-build `jakeneau@ironwood`.
- Lint every changed Markdown file.
- Run `git diff --check`.
- Do not run `nixos-anywhere`, switch, commit, or push.

## Tasks

- [ ] Add the Disko input and NixOS aspect.
- [ ] Add the reusable system and home server roles.
- [ ] Add Ironwood's declaration, SSH policy, and hardware layout.
- [ ] Add the headless graphics fact.
- [ ] Generate and authorize Ironwood's age identity.
- [ ] Add the Hetzner bootstrap and security documentation.
- [ ] Update indexes, cross-links, and the Tailscale TODO.
- [ ] Regenerate, format, stage, and validate the complete change.
- [ ] Present the verified install command without executing it.
