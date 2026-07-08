# Rebuild your home

Apply changes to your own home configuration. Lesson version:
[Your first home rebuild](../tutorials/first-home-rebuild.md).

## Steps

1. Edit through `~/.config/nix-config` — the symlink into your
   `modules/users/<you>/` folder in the live repo.

2. If you created a new file, stage it — flake evaluation ignores untracked
   files, so an unstaged new file is invisible to the rebuild:

   ```sh
   git add <the-new-file>
   ```

3. Rebuild and activate:

   ```sh
   hr
   ```

   `hr` is the autoloaded fish function
   (`modules/programs/fish/functions/hr.fish`); the full command it wraps is:

   ```sh
   home-manager switch -b backup --flake /etc/nixos#<you>@<host>       # Linux
   home-manager switch -b backup --flake /etc/nix-darwin#<you>@<host>  # macOS
   ```

   Don't quote the `<you>@<host>` fragment even for dotted usernames like
   `jake.neau` — home-manager takes everything after `#` raw and quotes it
   itself. Why `-b backup` is needed at all is explanation territory: see
   [the standalone home model](../explanation/standalone-homes.md).

`hr` rebuilds only your own home: no git operations, no flake input updates,
no system rebuild, nobody else's home.

## If it fails

- **Attribute missing / change not picked up:** the usual cause is an
  untracked new file — `git status`, then `git add` it.
- **Dry-build first** to see errors without activating anything:

  ```sh
  nix build '.#homeConfigurations."<you>@<host>".activationPackage' --no-link
  ```

- **A broken system config blocks home rebuilds:** your home eval reads host
  facts through the host's evaluated system config, so the system config must
  evaluate too. If someone left the repo non-evaluating, that has to be fixed
  first.
