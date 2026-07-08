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

  hostType = types.submodule {
    options = {
      class = lib.mkOption {
        type = types.enum ["nixos" "darwin"];
        description = "OS class: picks nixosSystem vs darwinSystem and the account-aspect class.";
      };

      system = lib.mkOption {
        type = types.str;
        example = "aarch64-darwin";
        description = "The host's platform (becomes nixpkgs.hostPlatform).";
      };

      users = lib.mkOption {
        type = types.listOf types.str;
        default = [];
        description = ''
          Users on this machine — the single authority: one entry yields the
          account (the factory aspect imported into the generated host-config
          aspect), the baseline delivery, and the
          homeConfigurations."<user>@<host>" output.
        '';
      };

      globalPrograms = lib.mkOption {
        type = types.listOf types.str;
        default = [];
        description = ''
          flake.programs names every user on this machine gets by default.
          Installs are opt-out-able per user via programs.<name>.enable.
        '';
      };

      installOverrides = lib.mkOption {
        type = types.attrsOf types.str;
        default = {};
        example = {firefox = "cask";};
        description = ''
          Per-program install-way override: picks a declared non-default way
          for this host (per-user "home" wins by default). Reroutes both
          halves of a globalPrograms entry, and user-declaration resolution
          honors it too — filtering entries it routes to a system install.
        '';
      };

      baselines = lib.mkOption {
        type = types.listOf types.str;
        default = [];
        example = ["role-desktop" "niri-desktop"];
        description = ''
          flake.modules.homeManager aggregate names (roles and extras like
          niri-desktop) this host's generated baseline inherits.
        '';
      };
    };
  };

  # ---------------------------------------------------------------------
  # The boundary priority wrapper
  # ---------------------------------------------------------------------
  # Shared config a home receives — the baseline, role compounds, program
  # units, user-declaration units — is lowered to priority 900 once, here
  # at stamping: user config (100) beats repo shared config (900) beats
  # upstream modules' internal mkDefaults (1000). The user's own aspect is
  # never wrapped — it is the overriding layer.
  #
  # Stamping leaf-by-leaf (if-outside/override-inside) works around a
  # nixpkgs module-system wart: dischargeProperties doesn't look inside
  # override markers, so one outer mkDefault breaks any mkIf underneath.
  # If nixpkgs ever fixes that, simplify this to one mkDefault per unit.

  # Value level: descend the config value tree, stamping leaves.
  wrapValue = v:
    if v ? _type
    then
      if v._type == "if"
      then v // {content = wrapValue v.content;}
      else if v._type == "merge"
      then v // {contents = map wrapValue v.contents;}
      # An explicit mkForce / mkDefault / mkOverride: the author chose a
      # priority — leave it untouched.
      else if v._type == "override"
      then v
      # Other markers (mkOrder, ...) are leaves; stamping outside them is
      # safe — filterOverrides strips the override before sorting.
      else lib.mkOverride 900 v
    # Store-path-like attrsets (flake inputs, fetched sources): plumbing
    # data, typically inside opaque (types.attrs/raw/unspecified) options
    # where a marker stamped on the paths inside would never be discharged
    # and leaks raw (e.g. stylix's internal stylix.inputs). Leave whole.
    else if lib.isAttrs v && v ? outPath && !lib.isDerivation v
    then v
    else if lib.isAttrs v && !lib.isDerivation v
    then lib.mapAttrs (_: wrapValue) v
    # Functions stay unstamped for the same opaque-option reason: they're
    # plumbing (lib helpers, overlay and package functions), not settings.
    else if lib.isFunction v
    then v
    # Leaves: scalars, lists, derivations.
    else lib.mkOverride 900 v;

  # Config level: like wrapValue, but keep the top-level `lib` and
  # `_module` keys unstamped. Both are opaque to the module system (attrsOf
  # attrs / lazyAttrsOf raw) — markers stamped inside their values are
  # never discharged, so they'd leak raw to readers — and both carry
  # plumbing (e.g. stylix's config.lib.stylix helpers and its flake
  # module's _module.args.inputs), not user-facing settings.
  configPlumbingKeys = ["lib" "_module"];
  wrapConfig = c:
    if c ? _type
    then
      if c._type == "if"
      then c // {content = wrapConfig c.content;}
      else if c._type == "merge"
      then c // {contents = map wrapConfig c.contents;}
      else if c._type == "override"
      then c
      else lib.mkOverride 900 c
    else if lib.isAttrs c && !lib.isDerivation c
    then
      lib.mapAttrs (
        n: v:
          if lib.elem n configPlumbingKeys
          then v
          else wrapValue v
      )
      c
    else lib.mkOverride 900 c;

  # Graph level: recurse the module graph down to its config values.
  # Mirrors unifyModuleSyntax: full form is m ? config || m ? options;
  # a shorthand module is config apart from imports and metadata.
  moduleMetaKeys = ["_class" "_file" "key" "disabledModules" "require"];
  wrapModule = m:
    if builtins.isPath m
    then wrapModule (import m)
    # Mirror the function args so the module system still injects pkgs &c.
    else if lib.isFunction m
    then lib.mirrorFunctionArgs m (args: wrapModule (m args))
    # A property marker as the whole module body (a top-level mkMerge/mkIf):
    # the entire value is config — wrap it as one, not per-attribute.
    else if m ? _type
    then wrapConfig m
    else if m ? config || m ? options
    # Full form: config value-wrapped, imports recursed, other keys kept.
    then
      m
      // {config = wrapConfig (m.config or {});}
      // lib.optionalAttrs (m ? imports) {imports = map wrapModule m.imports;}
    else
      lib.mapAttrs (
        n: v:
          if n == "imports"
          then map wrapModule v
          else if lib.elem n (moduleMetaKeys ++ configPlumbingKeys)
          then v
          else wrapValue v
      )
      m;

  # ---------------------------------------------------------------------
  # Generated aspects: install-way routing + baseline + host-config
  # ---------------------------------------------------------------------

  platformOf = class:
    {
      nixos = "linux";
      darwin = "macos";
    }.${
      class
    };

  generate = name: host: let
    fail = message: throw "flake.hosts.${name}: ${message}";
    platform = platformOf host.class;

    ways = program:
      if config.flake.programs ? ${program}
      then config.flake.programs.${program}.install.${platform}
      else fail "requests program \"${program}\", which has no flake.programs declaration; declare it or drop the entry";

    # The way chosen for (program, this host): the override if set — it
    # must name a declared way — else per-user "home" when declared, else
    # the platform's sole system way.
    wayOf = program: let
      declared = ways program;
      override = host.installOverrides.${program} or null;
    in
      if override != null
      then
        if lib.elem override declared
        then override
        else fail "installOverrides.${program} = \"${override}\", but ${program} declares only ${builtins.toJSON declared} on ${platform}; pick a declared way or drop the override"
      else if lib.elem "home" declared
      then "home"
      else if declared != []
      then lib.head declared
      else fail "lists ${program} in globalPrograms, but it declares no install way on ${platform}; add one to flake.programs.${program}.install or drop the entry";

    # Force every override through wayOf so a bad one throws at
    # declaration eval, not first use.
    overridesValid = lib.all (p: wayOf p != null) (lib.attrNames host.installOverrides);

    globals =
      map (program: {
        inherit program;
        way = wayOf program;
      })
      host.globalPrograms;

    # Route each global program's parts by its resolved way: the system
    # half into the host-config aspect, the HM half (full unit, or -config
    # for system-installed ones) into the baseline — an override reroutes
    # both halves by construction.
    systemUnits =
      map (g: inputs.self.modules.${host.class}.${g.program})
      (lib.filter (g: g.way != "home") globals);
    baselineUnits =
      map (
        g:
          inputs.self.modules.homeManager.${
            if g.way == "home"
            then g.program
            else "${g.program}-config"
          }
      )
      globals;

    baseline = {
      imports =
        map (n: inputs.self.modules.homeManager.${n}) host.baselines
        ++ baselineUnits
        ++ [
          # Host facts read through the evaluated system config — neither
          # sharedModules nor osConfig exists on the standalone path.
          {hostConstants = inputs.self."${host.class}Configurations".${name}.config.hostConstants;}
        ];
    };

    hostConfig = {
      # Account definition stays in the factory; placement is this
      # declaration's job — users lists each account exactly once.
      imports =
        map (u: inputs.self.modules.${host.class}.${u}) host.users
        ++ systemUnits;
    };
  in
    assert overridesValid; {
      ${host.class}."${name}-host-config" = hostConfig;
      homeManager."${name}-baseline" = baseline;
    };

  # ---------------------------------------------------------------------
  # Output stamping
  # ---------------------------------------------------------------------

  # The declared host = its hand-written aspect (quirks, constants, role
  # imports) + the generated host-config aspect.
  stampSystem = name: host: let
    modules = [
      inputs.self.modules.${host.class}.${name}
      inputs.self.modules.${host.class}."${name}-host-config"
      {nixpkgs.hostPlatform = lib.mkDefault host.system;}
    ];
  in
    if host.class == "nixos"
    then inputs.nixpkgs.lib.nixosSystem {inherit modules;}
    else inputs.nix-darwin.lib.darwinSystem {inherit modules;};

  systemsFor = class:
    lib.mapAttrs stampSystem
    (lib.filterAttrs (_: host: host.class == class) config.flake.hosts);

  stampHomes = name: host:
    lib.listToAttrs (map (u: {
        name = "${u}@${name}";
        value = inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = inputs.nixpkgs.legacyPackages.${host.system};
          modules =
            # The user's own aspect is the overriding layer — never wrapped.
            [inputs.self.modules.homeManager.${u}]
            ++ map wrapModule (
              [
                inputs.self.modules.homeManager."${name}-baseline"
                inputs.self.modules.homeManager.common-nixpkgs
              ]
              ++ config.flake.lib.homeUnits u name
            );
        };
      })
      host.users);
in {
  # One structured declaration per host: the generator routes each global
  # program's parts by its resolved install way, generates the per-host
  # baseline and host-config aspects, and stamps the flake outputs —
  # subsuming the per-host flake-parts.nix boilerplate.

  options.flake.hosts = lib.mkOption {
    type = types.attrsOf hostType;
    default = {};
    description = "Host declarations, each generating aspects and flake outputs.";
  };

  config.flake = {
    modules = lib.mkMerge (lib.mapAttrsToList generate config.flake.hosts);
    nixosConfigurations = systemsFor "nixos";
    darwinConfigurations = systemsFor "darwin";
    homeConfigurations = lib.mkMerge (lib.mapAttrsToList stampHomes config.flake.hosts);
  };
}
