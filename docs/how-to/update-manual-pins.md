# Update the manual pins

`nrr` moves every input forward except the few pins below. Each one names a
version in the config, so it changes only when you edit it. Why these pins
exist: [Nothing is pinned by hand](../explanation/flake-machinery.md#nothing-is-pinned-by-hand).

After every update, validate with the dry builds in `AGENTS.md`, then run `nr`.

## Get a new hash

Several steps below need a new hash. Replace the old value with `lib.fakeHash`,
build, and copy the hash from the `got:` line of the error:

```sh
nix build '.#homeConfigurations."<user>@<host>".activationPackage' --no-link
```

## OpenPencil

Location: `modules/programs/openpencil/`. The desktop app, `openpencil-mcp`,
and the `openpencil` CLI must share one version. Update all three together.

1. Find the latest release on
   [GitHub](https://github.com/open-pencil/open-pencil/releases/latest).
2. In `openpencil.nix`, set `version`.
3. In `npm/package.json`, set `version` and both `@open-pencil/*`
   dependencies to the same version.
4. Regenerate the npm lockfile:

   ```sh
   cd modules/programs/openpencil/npm
   nix shell nixpkgs#nodejs -c npm install --package-lock-only
   ```

5. Replace `npmDepsHash` with a new hash.
6. Take both release `hash` values from the release's `SHA256SUMS` file. Use
   the lines for `OpenPencil_aarch64.app.tar.gz` and
   `OpenPencil_<version>_amd64.AppImage`, and convert each one:

   ```sh
   nix hash convert --hash-algo sha256 <hex>
   ```

## pi-usage-limits

Location: the `pi-usage-limits` input in `modules/programs/pi/pi.nix`. The
package exists only on npm, and the npm tarball URL names its version.

1. Check the latest version:

   ```sh
   nix shell nixpkgs#nodejs -c npm view pi-usage-limits version
   ```

2. Change both version numbers in the input URL.
3. Regenerate `flake.nix` and lock the input:

   ```sh
   nix run .#write-flake
   nix flake lock
   ```

4. The local patches `patches/pi-usage-limits-*.patch` must still apply. If the
   build reports a failed hunk, refresh the patch against the new source.

## codediff.nvim

Location: the `codediff-nvim.overrideAttrs` block in
`modules/programs/nvf/nvf.nix`, held at 3.1.4.

Remove the whole override once Neovim restores its tall-filler scrollbind fix
([neovim#41820](https://github.com/neovim/neovim/issues/41820)). The nixpkgs
package then applies again and needs no further updates.

## Minecraft server

Location: `pkgs.purpurServers.purpur-1_21_11` in
`modules/hosts/redwood/configuration.nix`.

A newer server upgrades the world permanently, and older clients can no longer
join.

1. Confirm that every player's client supports the new game version.
2. Back up the world directory.
3. Change the attribute to the matching `purpur-*` version.
