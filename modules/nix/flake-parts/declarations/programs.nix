{
  lib,
  config,
  ...
}: let
  inherit (lib) types;

  # ---------------------------------------------------------------------
  # Declaration schema
  # ---------------------------------------------------------------------

  programType = types.submodule ({name, ...}: {
    options = {
      install = {
        linux = lib.mkOption {
          type = types.listOf (types.enum ["home" "system"]);
          default = [];
          description = ''
            Install ways on Linux: "home" (per-user, home-manager) and/or
            "system" (NixOS system packages).
          '';
        };
        macos = lib.mkOption {
          type = types.listOf (types.enum ["home" "cask"]);
          default = [];
          description = ''
            Install ways on macOS: "home" (per-user, home-manager) and/or
            "cask" (a homebrew cask — inherently machine-global).
          '';
        };
      };

      config = lib.mkOption {
        type = types.deferredModule;
        default = {};
        description = ''
          The program's shared home-manager default config, in any module
          form (shorthand attrset, full module, or module function).
          Carried plain: user-overridability comes from the boundary
          priority wrapper applied at host stamping, never from priority
          markers here.
        '';
      };

      hasEnableOption = lib.mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether home-manager itself provides programs.<name>.enable.
          When false, the generated install unit declares that toggle and
          installs pkgs.<name> behind it, so opting out stays the uniform
          `programs.<name>.enable = false;`.
        '';
      };

      packages = lib.mkOption {
        type = types.functionTo (types.listOf types.package);
        default = pkgs: [pkgs.${name}];
        defaultText = lib.literalExpression "pkgs: [pkgs.<name>]";
        description = ''
          The packages the generated toggle installs, as a function of pkgs.
          Only consulted when hasEnableOption is false — with a real HM
          module, home-manager installs the package itself. Covers programs
          whose attr differs from the declaration name or that install
          several packages.
        '';
      };

      handWritten = lib.mkOption {
        type = types.listOf (types.enum ["nixos" "darwin" "homeManager"]);
        default = [];
        description = ''
          Classes whose aspect for this program is hand-written. The
          generator emits nothing for them — no unit, no tombstone —
          because flake.modules merges same-name definitions, so a
          generated tombstone would poison the hand-written aspect.
        '';
      };
    };
  });

  # ---------------------------------------------------------------------
  # Unit generation
  # ---------------------------------------------------------------------

  # A plausible-but-unsupported unit: importing it fails readably instead
  # of with an "attribute ... missing" error.
  tombstone = name: message: {
    assertions = [
      {
        assertion = false;
        message = "flake.programs.${name}: ${message}";
      }
    ];
  };

  generate = name: decl: let
    fail = message: throw "flake.programs.${name}: ${message}";
    suppressed = class: lib.elem class decl.handWritten;

    homePlatforms = lib.filter (p: lib.elem "home" decl.install.${p}) ["linux" "macos"];
    hasHome = homePlatforms != [];
    hasSystem = lib.elem "system" decl.install.linux;
    hasCask = lib.elem "cask" decl.install.macos;

    # The per-user install: platform-gated on content (imports are never
    # conditional) and hung off an overridable boolean, so opting out is
    # always the uniform `programs.<name>.enable = false;`.
    installUnit = {
      pkgs,
      lib,
      config,
      ...
    }: let
      gate =
        (lib.elem "linux" homePlatforms && pkgs.stdenv.isLinux)
        || (lib.elem "macos" homePlatforms && pkgs.stdenv.isDarwin);
    in {
      imports = [decl.config];

      options = lib.optionalAttrs (!decl.hasEnableOption) {
        programs.${name}.enable = lib.mkEnableOption name;
      };

      config = lib.mkIf gate (lib.mkMerge [
        {programs.${name}.enable = true;}
        (lib.optionalAttrs (!decl.hasEnableOption) {
          # Plain: the boundary wrapper exempts lists, so this concatenates
          # with a user's own home.packages like an upstream HM module's.
          home.packages = lib.mkIf config.programs.${name}.enable (decl.packages pkgs);
        })
      ]);
    };

    units =
      lib.optionalAttrs (!suppressed "homeManager") {
        homeManager = {
          ${name} =
            if hasHome
            then installUnit
            else tombstone name "declares no per-user install way; import homeManager.${name}-config for the config alone, or add \"home\" to an install.<platform> list";
          # Config only, carried plain — for users on machines where the
          # install is global/system-level.
          "${name}-config" =
            if decl.hasEnableOption && (hasSystem || hasCask)
            then {
              imports = [decl.config];
              # the host generator routes -config only alongside a true-system
              # install, so null the package: enabling then configures the
              # system-installed app instead of double-installing the nix one
              programs.${name}.package = null;
            }
            else decl.config;
        };
      }
      // lib.optionalAttrs (!suppressed "nixos") {
        nixos.${name} =
          if hasSystem
          then {pkgs, ...}: {environment.systemPackages = [pkgs.${name}];}
          else tombstone name "declares no Linux \"system\" install way; import homeManager.${name}, or add \"system\" to install.linux";
      }
      // lib.optionalAttrs (!suppressed "darwin") {
        darwin.${name} =
          if hasCask
          then {homebrew.casks = [name];}
          else tombstone name "declares no macOS \"cask\" install way; import homeManager.${name}, or add \"cask\" to install.macos";
      };
  in
    # Incoherent declarations fail here, at declaration eval, before any
    # unit is imported anywhere.
    if decl.install.linux == [] && decl.install.macos == []
    then fail "declares no install way on any platform; set install.linux and/or install.macos, or delete the declaration"
    else if hasHome && suppressed "homeManager"
    then fail "declares a per-user (\"home\") install way but marks homeManager hand-written; drop the way or the handWritten entry"
    else if hasSystem && suppressed "nixos"
    then fail "declares the Linux \"system\" install way but marks nixos hand-written; drop the way or the handWritten entry"
    else if hasCask && suppressed "darwin"
    then fail "declares the macOS \"cask\" install way but marks darwin hand-written; drop the way or the handWritten entry"
    else units;
in {
  # One structured declaration per program, living in that program's
  # feature folder; the generator turns each into importable
  # flake.modules units — one per declared install way, plus the plain
  # -config unit. Flake-level machinery beside the dendritic tree, not a
  # feature module itself.

  options.flake.programs = lib.mkOption {
    type = types.attrsOf programType;
    default = {};
    description = "Program declarations, each generating flake.modules units.";
  };

  config.flake.modules = lib.mkMerge (lib.mapAttrsToList generate config.flake.programs);
}
