{
  # TEMPORARY — delete once nix-darwin#1819 lands and inputs move past it.
  # nixpkgs removed nixos-render-docs' --toc-depth flag, which nix-darwin's
  # manual build still passes, so every darwin build fails on darwin-manual-html
  # (nix-darwin#1817). Skip the HTML manual, and the uninstaller whose embedded
  # system builds its own copy; man pages are unaffected.
  flake.modules.darwin.manual-workaround = {
    documentation.doc.enable = false;
    system.tools.darwin-uninstaller.enable = false;
  };
}
