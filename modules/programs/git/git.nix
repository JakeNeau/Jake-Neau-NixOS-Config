{
  # git identity in two aspects so it matches at both levels: the home-manager
  # aspect for per-user git, the nixos aspect for system-level /etc/gitconfig.
  flake.modules.homeManager.git = {lib, ...}: {
    programs.git = {
      enable = true;
      settings.user = {
        name = "Jake Neau";
        email = "jakeneau@proton.me";
      };
      # nix runs as the user against the root-owned config repo; without this
      # allowlist libgit2 refuses to open it. libgit2 matches only the *resolved*
      # real path — /private/etc/nix-darwin on macOS, where /etc is a symlink to
      # /private/etc. The /etc spellings stay for the git CLI, which also accepts
      # the path as typed. Linux has no such indirection, hence no /private/etc/nixos.
      settings.safe.directory = [
        "/etc/nixos"
        "/etc/nix-darwin"
        "/private/etc/nix-darwin"
      ];
      # git creates .git files at umask 022 — no group-write — leaving the tree's
      # ACL the only grant of config-group access. New files only; existing ones
      # still need a chmod g+w. Root-run `nr` git reads this config only when sudo
      # keeps HOME: macOS sudo does, NixOS sudo resets it, so there this covers
      # user-run git only.
      includes = [
        {
          condition = "gitdir:/etc/nixos/"; # trailing slash: without it nothing matches
          contents.core.sharedRepository = "group";
        }
        {
          # git matches gitdir: against the resolved real path, and /etc is a
          # symlink to /private/etc — so this is the only spelling that catches
          # every access form, notably the `sudo git -C` all of `nr` runs through.
          condition = "gitdir:/private/etc/nix-darwin/";
          contents.core.sharedRepository = "group";
        }
      ];
    };

    # ~/.gitconfig is read after the managed ~/.config/git/config, so it silently
    # wins on every key it sets — but it is the user's file, so warn, never act.
    # Activation runs under `set -eu`: neither the test nor the printf may fail it.
    home.activation.warnUnmanagedGitconfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
      if [ -e "$HOME/.gitconfig" ]; then
        printf '%s\n' \
          "warning: ~/.gitconfig exists and is not managed by Nix." \
          "  git reads it after the managed ~/.config/git/config, so whichever keys" \
          "  it sets silently override the declarative ones." \
          "  Fix: move any setting worth keeping into modules/programs/git/git.nix," \
          "  then delete ~/.gitconfig." >&2 || true
      fi
    '';
  };

  flake.modules.nixos.git = {
    programs.git = {
      enable = true;
      config = {
        user.name = "Jake Neau";
        user.email = "jakeneau@proton.me";
        init.defaultBranch = "main";
      };
    };
  };
}
