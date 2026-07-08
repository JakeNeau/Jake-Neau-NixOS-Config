# Run the Minecraft server

Minecraft servers are declarative (nix-minecraft) and run as systemd services
on the NixOS host that imports the feature — today `redwood`. The `mc-*` fish
helpers (`modules/programs/fish/functions/`) wrap the systemd units; they are
only installed on hosts whose `hostConstants.minecraftServer` fact is set,
which importing `modules/nix/tools/nix-minecraft` does automatically.

## Control a server

Each declared server is a `minecraft-server-<name>.service` unit. The
helpers take the bare `<name>`:

```sh
mc-list                # every declared server and whether it's running
mc-start <name>        # sudo systemctl start (servers don't auto-start)
mc-stop <name>         # sudo systemctl stop
mc-logs <name>         # journalctl for the unit
mc-logs -f <name>      # ... and follow
```

Run without arguments, each command prints its usage plus the server list;
a wrong name gets the same list.

## Add or change a server

Server definitions live in the host's hand-written aspect —
`services.minecraft-servers.servers` in
`modules/hosts/redwood/configuration.nix` (the `enable` itself comes from
importing the nix-minecraft feature, not from the host):

```nix
services.minecraft-servers.servers.<name> = {
  enable = true;
  autoStart = false;   # start it with mc-start when wanted
  package = pkgs.purpurServers.purpur-1_21_11;
};
```

Rebuild the system (this is system-level, not a home change), then `mc-list`
shows the new unit.

## Give another host a server

Import the feature in that host's aspect:

```nix
imports = [inputs.self.modules.nixos.nix-minecraft];
```

Importing it *means* "this host runs a minecraft server": it enables the
service and sets the `hostConstants.minecraftServer` fact (which is what
turns the `mc-*` helpers on) in one move. Then declare the `servers` entries
in the host's aspect as above. NixOS only — the service is systemd-based.
