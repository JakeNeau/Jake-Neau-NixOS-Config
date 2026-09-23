{
  # What `nix fmt` runs: nixfmt over the whole tree, in the RFC 166 style
  # nixpkgs itself uses. The tree wrapper is needed because a bare `nix fmt`
  # passes no paths, and plain nixfmt then reads stdin.
  perSystem = { pkgs, ... }: { formatter = pkgs.nixfmt-tree; };
}
