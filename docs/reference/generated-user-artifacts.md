# Generated user artifacts reference

What the user factory (`flake.factory.user`,
`modules/factory/user/user.nix`) stamps from `(username, isAdmin)`. Each
user's folder instantiates it:
`flake.modules = inputs.self.factory.user "<user>" <isAdmin>;`
(see `modules/users/*`). The recipe: [Add a
user](../how-to/add-a-user.md).

## nixos.\<user\> — the NixOS account aspect

- `users.users.<user>.isNormalUser = true`;
- `home = "/home/<user>"`;
- `extraGroups = ["networkmanager"]`, plus `"wheel"` when `isAdmin`;
- `shell = pkgs.fish`.

## darwin.\<user\> — the darwin account aspect

macOS owns the account itself; nix-darwin only records:

- `users.users.<user>.home = "/Users/<user>"`;
- `system.primaryUser = <user>` when `isAdmin`.

Account aspects are *placed* into a host by the hosts generator, from
`flake.hosts.<h>.users` (see [generated host
artifacts](generated-host-artifacts.md)).

## homeManager.\<user\> — the user's home aspect

The unwrapped overriding layer of the user's stamped
`homeConfigurations."<user>@<host>"` outputs. The factory contributes:

- `home.username = "<user>"` (`home.homeDirectory` and
  `home.stateVersion` come from `role-minimal` in the host baseline,
  `modules/host-config/roles/minimal/homeManager-minimal.nix`);
- the `~/.config/nix-config` symlink.

Per-user config layered on top lives in `modules/users/<user>/`.

## The ~/.config/nix-config symlink contract

- Target: the user's own folder in the live repo —
  `/etc/nix-darwin/modules/users/<user>` on macOS,
  `/etc/nixos/modules/users/<user>` on Linux.
- Out-of-store: created with `config.lib.file.mkOutOfStoreSymlink`, so it
  points at the repo, not a store copy — edits show up immediately without
  a rebuild.
- Lands at home activation, declaratively; no imperative step.
