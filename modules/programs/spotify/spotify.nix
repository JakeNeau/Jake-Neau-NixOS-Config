{
  # Spotify, wrapped to launch with --in-process-gpu.
  #
  # Its bundled CEF (Chromium) can't start a separate GPU process on this
  # dual-GPU AMD machine and aborts ("GPU process isn't usable"); running GPU
  # work in-process sidesteps it. Known upstream CEF/Mesa bug (nixpkgs#228586),
  # not a config issue. Periodically test a bare `spotify`: once it launches
  # without the flag, the upstream fix has landed and this whole module can go.
  flake.modules.nixos.spotify = {pkgs, ...}: {
    environment.systemPackages = [
      (pkgs.symlinkJoin {
        name = "spotify";
        paths = [pkgs.spotify];
        nativeBuildInputs = [pkgs.makeWrapper];
        postBuild = ''wrapProgram $out/bin/spotify --add-flags "--in-process-gpu"'';
      })
    ];
  };
}
