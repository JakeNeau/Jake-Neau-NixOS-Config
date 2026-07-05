{
  # The `config` group owns this flake repo so its members can edit the
  # configuration without sudo, while the tree itself stays root-owned. Users get
  # no write access until they are listed explicitly, so adding a future user
  # never silently grants them the config — membership is current users only.
  #
  # The group is declared declaratively per platform; converting a root-owned
  # checkout into a group-writable one is a one-time imperative filesystem step (it
  # can't live in Nix without a recursive chown that would also clobber secrets/).
  # Run it once per machine from the repo root, *after* this group exists on the
  # system (i.e. after the next rebuild), then log out/in (or `newgrp config`).
  #
  # Linux (/etc/nixos) — POSIX ACLs via setfacl:
  #   sudo chgrp -R config .                       # group owns every file
  #   sudo chmod -R g+w .                          # members may write
  #   sudo find . -type d -exec chmod g+s {} +     # new files inherit the group
  #   sudo setfacl -R  -m g:config:rwX .           # existing files
  #   sudo setfacl -R -d -m g:config:rwX .         # default ACL keeps new files writable
  #   sudo chmod 600 secrets/keys.txt              # re-lock the sops age key (Linux only)
  #
  # macOS (/etc/nix-darwin) — native ACLs via `chmod +a` (no setfacl). nix-darwin
  # only creates/manages a group that is in users.knownGroups and given a gid:
  #   sudo chgrp -R config .
  #   sudo chmod -R g+w .
  #   sudo find . -type d -exec chmod g+s {} +
  #   sudo chmod -R +a "group:config allow read,write,execute,file_inherit,directory_inherit" .
  # (No keys.txt re-lock: the sops age key lives outside the repo on macOS.)

  flake.modules.nixos.config-group = {
    users.groups.config.members = ["jakeneau"];
  };

  flake.modules.darwin.config-group = {
    # macOS owns the account itself; nix-darwin will only create/manage a group
    # that is listed in knownGroups, and it needs an explicit gid (600 is free
    # here — the only custom gids are Apple's sharepoint groups at 701/702).
    users.knownGroups = ["config"];
    # account names differ per host, so each host aspect lists its own members
    users.groups.config.gid = 600;
  };
}
