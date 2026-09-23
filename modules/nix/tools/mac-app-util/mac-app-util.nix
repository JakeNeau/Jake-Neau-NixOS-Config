{ inputs, ... }: {
  # mac-app-util: register Nix-installed macOS .app bundles with LaunchServices
  # via real trampoline apps instead of nix-store symlinks. macOS ignores apps
  # reached through store symlinks, so without this a Nix app can't be made a
  # default handler -- `duti -s` writes an orphaned pref that never resolves, the
  # handler stays on the OS default, and the protected-type anti-hijacking modal
  # re-pops on every rebuild. Trampolines also make the apps visible to Spotlight
  # and Launchpad. https://github.com/hraban/mac-app-util

  flake-file.inputs.mac-app-util = {
    url = "github:hraban/mac-app-util";
    # mac-app-util is a Common Lisp program built with SBCL. Its own nixpkgs
    # pin ships SBCL 2.6.4, whose runtime cannot map its heap on macOS 27
    # ("failed to allocate ... at 0x300100000"), so every activation that
    # syncs trampolines crashes. Our nixpkgs' SBCL 2.6.8 builds and runs.
    inputs.nixpkgs.follows = "nixpkgs";
  };

  # Trampoline system apps (environment.systemPackages).
  flake.modules.darwin.mac-app-util = {
    imports = [ inputs.mac-app-util.darwinModules.default ];
  };

  # Trampoline every user's home-manager apps -- sioyek is installed through
  # home-manager, so this is what fixes its PDF default. Delivered through the
  # mac hosts' baselines.
  flake.modules.homeManager.mac-app-util = {
    imports = [ inputs.mac-app-util.homeManagerModules.default ];
  };
}
