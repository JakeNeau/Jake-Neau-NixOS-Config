# Your first program declaration

In this lesson you'll take a program all the way through the declaration
framework: declare it, request it for yourself, verify the build, and run it.
By the end you'll have exercised the full declare → generate → resolve →
rebuild loop that delivers every program in this repo.

You need `config` group membership and a working `hr` (do
[Your first home rebuild](first-home-rebuild.md) first), and a shell in the
repo root (`/etc/nixos` on Linux, `/etc/nix-darwin` on macOS).

We'll use GNU `hello` — a tiny program with no home-manager module of its own,
which lets you see the generator do the most work.

## 1. Write the declaration

Every program declaration lives in that program's own feature folder. Create
one:

```sh
mkdir modules/programs/hello
```

```nix
# modules/programs/hello/hello.nix
{
  flake.programs.hello = {
    install.linux = ["home"];
    install.macos = ["home"];
    hasEnableOption = false;
  };
}
```

Reading it field by field:

- `install.linux` / `install.macos` — the supported install ways per
  platform. `"home"` means a per-user home-manager install; the alternatives
  are `"system"` (Linux, NixOS system packages) and `"cask"` (macOS, a
  homebrew cask). Declaring `"home"` on both platforms makes hello available
  per-user everywhere.
- `hasEnableOption = false` — home-manager has no `programs.hello` module, so
  the generator supplies the `programs.hello.enable` toggle itself and
  installs `pkgs.hello` behind it. (For programs where the package attribute
  differs from the name, or several packages are needed, you'd add a
  `packages` field — the default is `pkgs: [pkgs.<name>]`.)

We declared no `config` field: hello has no settings to share. See the
[declaration schema reference](../reference/declaration-schema.md) for every
field.

## 2. Stage it

```sh
git add modules/programs/hello/hello.nix
```

Flake evaluation ignores untracked files, so without this the declaration
doesn't exist yet.

## 3. Look at what was generated

From this one declaration the generator produced an importable
`flake.modules.homeManager.hello` unit — the per-user install, hung off the
enable toggle so any user can opt out with `programs.hello.enable = false;`.
Confirm it exists:

```sh
nix eval '.#modules.homeManager' --apply 'm: m ? hello'
```

That prints `true`. Nothing imports the unit yet, though — declaring a program
makes it *available*; something must still request it. (The full catalog of
what a declaration generates, including the `-config` split and tombstones, is
the [generated-units reference](../reference/generated-units.md).)

## 4. Request it for yourself

There are two request channels: a host's `globalPrograms` list (every user on
that machine gets it) and your own `flake.users` declaration (just you). Use
the second. In your user folder, add the line to your user file — for example:

```nix
# in modules/users/jakeneau/jakeneau.nix (use your own name; quote dotted ones)
flake.users.jakeneau.programs = ["hello"];
```

`programs` means "on every machine I'm on". Had you wanted it on a single
machine, `flake.users.jakeneau.hosts.<host>.programs = ["hello"];` is the
per-host form.

## 5. Dry-build

Prove your home still builds before activating anything (replace user and
host; the quotes around the attribute name matter):

```sh
nix build '.#homeConfigurations."jakeneau@spruce".activationPackage' --no-link
```

If you mistyped the program name or requested something impossible, this is
where the framework tells you — declaration errors throw at evaluation time
with a message naming the fix.

## 6. Rebuild and run

```sh
hr
hello
```

`Hello, world!` — delivered by a declaration you wrote, resolved for your
platform, installed into your home.

## 7. Clean up

```sh
git rm -rf modules/programs/hello
```

Remove the `flake.users` line from your user file too, then:

```sh
hr
```

## Where to next

- The recipe version, with the fields for real programs (shared config,
  hand-written classes): [Add a program](../how-to/add-a-program.md).
- How a request resolves to an install way per (program, host), and when
  entries filter vs throw:
  [Install-way resolution](../explanation/install-way-resolution.md).
