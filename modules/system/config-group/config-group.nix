{
  # The `config` group owns this flake repo (/etc/nixos) so its members can edit
  # the configuration without sudo, while the tree itself stays root-owned. Users
  # get no write access until they are listed here explicitly, so adding a future
  # user never silently grants them the config — membership below is current
  # users only (jakeneau is the only human account on the NixOS hosts; the
  # work user is macOS-only).
  #
  # The group is declared declaratively; converting a root-owned checkout into a
  # group-writable one is a one-time imperative filesystem step — it can't live in
  # Nix without a recursive chown that would also clobber secrets/. Run once per
  # machine from the repo root, *after* this group exists on the system (i.e.
  # after the next rebuild), then log out/in (or `newgrp config`):
  #
  #   sudo chgrp -R config .                       # group owns every file
  #   sudo chmod -R g+w .                          # members may write
  #   sudo find . -type d -exec chmod g+s {} +     # new files inherit the group
  #   sudo setfacl -R  -m g:config:rwX .           # existing files
  #   sudo setfacl -R -d -m g:config:rwX .         # default ACL keeps new files writable
  #   sudo chmod 600 secrets/keys.txt              # re-lock the sops key afterwards

  flake.modules.nixos.config-group = {
    users.groups.config.members = ["jakeneau"];
  };
}
