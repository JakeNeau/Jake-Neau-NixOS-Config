# Your first home rebuild

In this lesson you'll make your first change to your own home configuration on
an existing host and watch it land — the whole edit → stage → rebuild loop you
will use from now on. It takes about ten minutes.

You need an account that an admin has already set up on this machine (per
[the adding-a-user guide](../how-to/add-a-user.md)): your user is listed on
the host, your home has been activated at least once, and you've been added to
the `config` group.

## 1. Confirm your group membership works

Members of the `config` group can edit the configuration repo without `sudo`.
Check that your shell session has it:

```sh
groups
```

If `config` is missing from the list, your membership was added after you
logged in — group changes only take effect on a fresh login. Log out and back
in, or start a subshell with the group active for now:

```sh
newgrp config
```

## 2. Find your own config folder

Every user gets a `~/.config/nix-config` symlink pointing at their personal
folder inside the live configuration repo:

```sh
cd ~/.config/nix-config
ls
pwd -P
```

`pwd -P` shows where you really are: `modules/users/<you>/` inside the repo
(`/etc/nixos` on Linux, `/etc/nix-darwin` on macOS). This is a symlink into
the live repo — not a copy — so anything you edit here is immediately the real
configuration. Everything in this folder is yours: files here are
auto-imported as part of the flake, and plain settings in your folder override
the shared defaults the host delivers.

## 3. Make a small change

Create a new file in the folder, declaring one extra package for your home.
Use your own username in place of `jakeneau` (quote it if it contains a dot,
e.g. `"jake.neau"`):

```nix
# ~/.config/nix-config/hello.nix
{
  flake.modules.homeManager.jakeneau = {pkgs, ...}: {
    home.packages = [pkgs.cowsay];
  };
}
```

This adds to your personal home-manager aspect — the same one your existing
`homeManager.nix` (if you have one) contributes to; same-name aspects merge.

## 4. Stage the new file

```sh
git add hello.nix
```

This step matters: Nix evaluates the flake from git's view of the tree, and
**untracked files are invisible to it**. A brand-new file that isn't at least
staged simply doesn't exist as far as the rebuild is concerned. (Edits to
already-tracked files don't need this.) Your `config` membership grants write
to the repo's `.git`, so you stage — and later commit — your own files.

## 5. Rebuild your home

```sh
hr
```

`hr` ("home rebuild") is an autoloaded fish function that rebuilds and
activates *your own* home configuration from the system flake — it runs
`home-manager switch -b backup --flake <repo>#<you>@<host>` for you. It
touches no one else's home and never touches the system config, so you can run
it freely.

## 6. See it land

```sh
cowsay "it works"
```

The package is on your PATH: your home configuration now includes it. That's
the whole loop — every change to your home goes edit → `git add` (if new) →
`hr`.

## 7. Clean up

Remove the experiment and rebuild once more:

```sh
git rm -f hello.nix
hr
```

`cowsay` is gone again. You've now made, applied, and reverted a home change
end to end.

## Where to next

- The compact recipe version of this loop:
  [Rebuild your home](../how-to/rebuild-your-home.md).
- Why exactly one channel delivers config to your home, and why `-b backup`:
  [The standalone home model](../explanation/standalone-homes.md).
