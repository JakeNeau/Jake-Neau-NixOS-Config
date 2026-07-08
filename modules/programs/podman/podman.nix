{
  # Podman: a daemonless container engine.
  #
  # NixOS: the virtualisation.podman module, with docker CLI compat.
  #        On every workstation via role-desktop.
  # macOS: nixpkgs has no podman module for darwin, so this installs the
  #        pieces by hand: the podman CLI, a `docker` shim, and the
  #        Apple-native VM stack (vfkit + gvproxy) that `podman machine`
  #        uses to run the Linux VM that containers actually live in.
  #        Imported per-host (currently only the work laptop).

  flake.modules.nixos.podman = {
    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true;
    };
  };

  flake.modules.darwin.podman = {pkgs, ...}: {
    environment.systemPackages = let
      # Transient workaround: nixpkgs marked podman linux-only 2026-06-28; the fix
      # isn't in the nixos-unstable channel yet. Re-add darwin to its platforms —
      # meta-only, so the derivation and cache hit are untouched.
      # Remove once the channel passes nixpkgs commit e2886083.
      podman = pkgs.podman.overrideAttrs (old: {
        meta = old.meta // {platforms = old.meta.platforms ++ pkgs.lib.platforms.darwin;};
      });

      # Provide a real `docker` binary symlinked to podman, mimicking NixOS's
      # virtualisation.podman.dockerCompat (which is unavailable on darwin).
      docker-podman = pkgs.runCommand "docker-podman" {} ''
        mkdir -p $out/bin
        ln -s ${podman}/bin/podman $out/bin/docker
      '';
    in [
      docker-podman # `docker` aliased to podman
      pkgs.docker-compose # Provider for podman compose
      pkgs.gvproxy # Network plumbing for native VMs
      podman # Daemonless container engine
      pkgs.vfkit # Apple's hypervisor for launching native VMs
    ];

    # Use Apple-native virtualization for `podman machine`.
    environment.variables.CONTAINERS_MACHINE_PROVIDER = "applehv";
  };
}
