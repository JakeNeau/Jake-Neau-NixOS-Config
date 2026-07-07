{inputs, ...}: {
  # Factory: stamp out a user across classes from (username, isAdmin).
  #
  #   (flake.factory.user "alice" true) => {
  #     nixos.alice = …; darwin.alice = …; homeManager.alice = …;
  #   }
  #
  # Instantiate with lib.mkMerge and layer per-user extras on top
  # (see modules/users/*). The home-manager wiring pulls in the user's
  # matching homeManager aspect on whichever system imports the user.

  config.flake.factory.user = username: isAdmin: {
    nixos.${username} = {
      lib,
      pkgs,
      ...
    }: {
      users.users.${username} = {
        isNormalUser = true;
        home = "/home/${username}";
        extraGroups = ["networkmanager"] ++ lib.optionals isAdmin ["wheel"];
        shell = pkgs.fish;
      };

      home-manager.users.${username}.imports = [
        inputs.self.modules.homeManager.${username}
      ];
    };

    darwin.${username} = {lib, ...}: {
      # macOS owns the account itself; nix-darwin only records its home dir
      # and (for the primary user) some user-scoped settings.
      users.users.${username}.home = "/Users/${username}";
      system.primaryUser = lib.mkIf isAdmin username;

      home-manager.users.${username}.imports = [
        inputs.self.modules.homeManager.${username}
      ];
    };

    homeManager.${username} = {
      config,
      pkgs,
      ...
    }: {
      home.username = username;

      # Out-of-store symlink into the live repo, so edits to the user's own
      # config folder show up immediately without a rebuild.
      home.file.".config/nix-config".source =
        config.lib.file.mkOutOfStoreSymlink
        "${
          if pkgs.stdenv.isDarwin
          then "/etc/nix-darwin"
          else "/etc/nixos"
        }/modules/users/${username}";
    };
  };
}
