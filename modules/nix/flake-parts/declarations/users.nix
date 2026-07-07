{
  lib,
  config,
  inputs,
  ...
}: let
  inherit (lib) types;

  # ---------------------------------------------------------------------
  # Declaration schema
  # ---------------------------------------------------------------------

  userType = types.submodule {
    options = {
      programs = lib.mkOption {
        type = types.listOf types.str;
        default = [];
        description = ''
          flake.programs names this user gets on every machine they're on.
          Resolved per host: an entry with no per-user way on the host's
          platform, or overridden to a system install, filters out silently.
        '';
      };

      hosts = lib.mkOption {
        type = types.attrsOf (types.submodule {
          options.programs = lib.mkOption {
            type = types.listOf types.str;
            default = [];
            description = "flake.programs names this user gets on this host only.";
          };
        });
        default = {};
        description = ''
          Per-host program requests — the per-user-per-host channel the
          other two declarations can't express.
        '';
      };
    };
  };

  # ---------------------------------------------------------------------
  # Resolution: per-(user, host) HM unit sets — never system parts
  # ---------------------------------------------------------------------

  platformOf = class:
    {
      nixos = "linux";
      darwin = "macos";
    }.${
      class
    };

  # The HM units one (user, host) pair resolves to; a user with no
  # declaration contributes nothing.
  homeUnits = user: hostName: let
    fail = message: throw "flake.users.${user}: ${message}";
    decl =
      config.flake.users.${
        user
      }
      or {
        programs = [];
        hosts = {};
      };
    host = config.flake.hosts.${hostName};
    platform = platformOf host.class;

    ways = forPlatform: program:
      if config.flake.programs ? ${program}
      then config.flake.programs.${program}.install.${forPlatform}
      else fail "requests program \"${program}\", which has no flake.programs declaration; declare it or drop the entry";

    # A user entry never causes a system install: it resolves to the
    # per-user way or filters out. The override-forced case filters, not
    # throws — the host provides the same program, so the request is
    # satisfied (the -config unit arrives through the baseline).
    resolvesToHome = program: let
      override = host.installOverrides.${program} or null;
    in
      lib.elem "home" (ways platform program)
      && (override == null || override == "home");

    # `programs` (all-hosts) filters silently per host, but a program with
    # no per-user way on any platform can never be per-user at all.
    allHosts =
      map (
        p:
          if lib.any (pl: lib.elem "home" (ways pl p)) ["linux" "macos"]
          then p
          else fail "programs lists ${p}, which declares no per-user (\"home\") install way on any platform; request it from a host's globalPrograms instead, or add a \"home\" way to flake.programs.${p}.install"
      )
      decl.programs;

    # `hosts.<h>.programs` named this host deliberately, so a program with
    # no per-user way on its platform contradicts the request.
    thisHost =
      map (
        p:
          if lib.elem "home" (ways platform p)
          then p
          else fail "hosts.${hostName}.programs lists ${p}, which declares no per-user (\"home\") install way on ${platform}; deliver it via flake.hosts.${hostName}.globalPrograms instead, or add a \"home\" way to flake.programs.${p}.install.${platform}"
      )
      (decl.hosts.${hostName}.programs or []);

    # hosts.<h> must name a host this user is listed on.
    listedOn = lib.attrNames (lib.filterAttrs (_: h: lib.elem user h.users) config.flake.hosts);
    unlisted = lib.filter (h: !(lib.elem h listedOn)) (lib.attrNames decl.hosts);
  in
    if unlisted != []
    then fail "hosts.${lib.head unlisted} names a host this user is not listed on; add \"${user}\" to flake.hosts.${lib.head unlisted}.users or drop the entry"
    else
      map (p: inputs.self.modules.homeManager.${p})
      (lib.filter resolvesToHome (lib.unique (allHosts ++ thisHost)));
in {
  # One structured declaration per user: the per-user program channels the
  # program and host declarations can't express, resolved against
  # flake.programs per (program, host) into home-manager units only.

  options.flake.users = lib.mkOption {
    type = types.attrsOf userType;
    default = {};
    description = "User declarations, each resolving to per-(user, host) HM unit sets.";
  };

  config.flake.lib.homeUnits = homeUnits;
}
