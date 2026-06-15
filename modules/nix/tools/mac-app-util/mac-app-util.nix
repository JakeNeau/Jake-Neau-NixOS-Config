{inputs, ...}: {
  # mac-app-util: register Nix-installed macOS .app bundles with LaunchServices
  # via real trampoline apps instead of nix-store symlinks. macOS ignores apps
  # reached through store symlinks, so without this a Nix app can't be made a
  # default handler -- `duti -s` writes an orphaned pref that never resolves, the
  # handler stays on the OS default, and the protected-type anti-hijacking modal
  # re-pops on every rebuild. Trampolines also make the apps visible to Spotlight
  # and Launchpad. https://github.com/hraban/mac-app-util

  flake-file.inputs.mac-app-util.url = "github:hraban/mac-app-util";
  # Deliberately NOT `inputs.nixpkgs.follows = "nixpkgs"`. mac-app-util is a
  # Common Lisp program built with SBCL; our nixpkgs ships SBCL 2.6.4, whose
  # fare-quasiquote build dies in named-readtables ("Bug in readtable iterators
  # or concurrent access?" -- a #\Nul reader-macro conflict). Letting it keep
  # its own pinned nixpkgs (SBCL 2.5.7) sidesteps the broken toolchain. The
  # extra nixpkgs only feeds this build-time tool, so the closure cost is small.

  # Trampoline both system apps (environment.systemPackages, via the darwin
  # module) and every user's home-manager apps (via sharedModules) -- sioyek is
  # installed through home-manager, so the latter is what fixes its PDF default.
  flake.modules.darwin.mac-app-util = {
    imports = [inputs.mac-app-util.darwinModules.default];
    home-manager.sharedModules = [inputs.mac-app-util.homeManagerModules.default];
  };
}
