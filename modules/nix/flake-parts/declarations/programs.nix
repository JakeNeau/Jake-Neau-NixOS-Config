{
  lib,
  config,
  ...
}:
let
  inherit (lib) types;

  # ---------------------------------------------------------------------
  # Declaration schema
  # ---------------------------------------------------------------------

  platforms = [
    "linux"
    "macos"
  ];

  # One block per platform plus `shared`, each with the same four fields.
  blockType =
    {
      ways,
      waysDescription,
      systemClass,
    }:
    types.submodule {
      options = {
        install = lib.mkOption {
          type = types.listOf (types.enum ways);
          default = [ ];
          description = waysDescription;
        };

        config = lib.mkOption {
          type = types.deferredModule;
          default = { };
          description = ''
            Home-manager config, in any module form (shorthand attrset, full
            module, or module function). Carried plain: user-overridability
            comes from the boundary priority wrapper applied at host
            stamping, never from priority markers here. A platform block's
            config applies on its platform only, and its option
            declarations apply everywhere.
          '';
        };

        systemConfig = lib.mkOption {
          type = types.nullOr types.deferredModule;
          default = null;
          description = ''
            Extra ${systemClass} module the machine-wide install imports:
            daemons, setuid wrappers, activation scripts, and other
            machine-level config a package alone cannot provide.
          '';
        };

        packages = lib.mkOption {
          type = types.nullOr (types.functionTo (types.listOf types.package));
          default = null;
          description = ''
            Packages the generated toggle installs, as a function of pkgs.
            Only consulted when hasEnableOption is false. When no block sets
            packages, the toggle installs pkgs.<name>.
          '';
        };
      };
    };

  programType = types.submodule {
    options = {
      shared = lib.mkOption {
        type = blockType {
          ways = [
            "home"
            "custom"
          ];
          waysDescription = ''
            Install ways on both platforms: "home" (per-user, home-manager)
            and/or "custom" (machine-wide, installed by systemConfig).
          '';
          systemClass = "module, valid in both NixOS and nix-darwin,";
        };
        default = { };
        description = "What applies on both platforms; each platform block comes first.";
      };

      linux = lib.mkOption {
        type = blockType {
          ways = [
            "home"
            "system"
            "custom"
          ];
          waysDescription = ''
            Install ways on Linux: "home" (per-user, home-manager), "system"
            (NixOS system packages), and/or "custom" (installed by
            systemConfig).
          '';
          systemClass = "NixOS";
        };
        default = { };
        description = "What applies on Linux only.";
      };

      macos = lib.mkOption {
        type = blockType {
          ways = [
            "home"
            "cask"
            "custom"
          ];
          waysDescription = ''
            Install ways on macOS: "home" (per-user, home-manager), "cask" (a
            homebrew cask, inherently machine-global), and/or "custom"
            (installed by systemConfig).
          '';
          systemClass = "nix-darwin";
        };
        default = { };
        description = "What applies on macOS only.";
      };

      hasEnableOption = lib.mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether home-manager itself provides programs.<name>.enable.
          When false, the generated install unit declares that toggle and
          installs the platform's packages behind it, so opting out of a
          home install stays the uniform `programs.<name>.enable = false;`.
        '';
      };

      handWritten = lib.mkOption {
        type = types.listOf (
          types.enum [
            "nixos"
            "darwin"
            "homeManager"
          ]
        );
        default = [ ];
        description = ''
          Classes whose aspect for this program is hand-written. The
          generator emits nothing for them — no unit, no tombstone —
          because flake.modules merges same-name definitions, so a
          generated tombstone would poison the hand-written aspect.
        '';
      };

      excludeFromVpn = lib.mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether this program's traffic bypasses every VPN installed on the
          host. On Linux its install adds a higher-priority wrapped copy
          that runs hostConstants.vpn.excludeCommands first. On macOS
          activation passes its app executable to every
          hostConstants.vpn.syncExcludedApps command.
        '';
      };
    };
  };

  # A platform's effective install ways: its own block's, then shared's.
  installWays = decl: platform: decl.${platform}.install ++ decl.shared.install;

  # ---------------------------------------------------------------------
  # VPN exclusion (excludeFromVpn)
  # ---------------------------------------------------------------------

  # Linux: a copy of pkg whose executables run every VPN's exclude line,
  # then exec the original. exec keeps the PID, so the program and its
  # children stay excluded. Desktop entries naming pkg point at the copy.
  vpnExcludedCopy =
    pkgs: commands: pkg:
    let
      excludeLines = pkgs.writeText "vpn-exclude-commands" (lib.concatLines commands);
    in
    pkgs.symlinkJoin {
      name = "${lib.getName pkg}-vpn-excluded";
      paths = [ pkg ];
      postBuild = ''
        shopt -s nullglob
        # lndir links a symlinked directory whole; make it a real directory of links
        realDir() {
          if [ -L "$1" ]; then
            target=$(readlink -f "$1")
            rm "$1"
            mkdir "$1"
            ${lib.getExe' pkgs.lndir "lndir"} -silent "$target" "$1"
          fi
        }
        realDir "$out/bin"
        for exe in ${pkg}/bin/*; do
          wrapper="$out/bin/''${exe##*/}"
          rm "$wrapper"
          {
            echo '#!${pkgs.runtimeShell}'
            cat ${excludeLines}
            printf 'exec %s "$@"\n' "$exe"
          } > "$wrapper"
          chmod +x "$wrapper"
        done
        for entry in ${pkg}/share/applications/*.desktop; do
          if grep -q '^Exec=.*${pkg}' "$entry"; then
            realDir "$out/share"
            realDir "$out/share/applications"
            copy="$out/share/applications/''${entry##*/}"
            rm "$copy"
            sed '/^Exec=/s|${pkg}|'"$out"'|g' "$entry" > "$copy"
          fi
        done
      '';
    };

  # macOS: shell that collects app executables into vpnExcludedPaths.
  # A missing bundle warns and is skipped, never failing activation.
  addAppExecutable = ''
    vpnExcludedPaths=()
    vpnAddAppExecutable() {
      local exe
      exe=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$1/Contents/Info.plist" 2>/dev/null) || exe=
      if [ -n "$exe" ] && [ -x "$1/Contents/MacOS/$exe" ]; then
        vpnExcludedPaths+=("$1/Contents/MacOS/$exe")
      else
        printf '\033[1;33mwarning:\033[0m %s has no app bundle at %s; it stays in the VPN\n' "$2" "$1" >&2
      fi
    }
  '';

  # Run every VPN's sync command with this writer's state file and paths.
  # An unavailable VPN warns, never failing activation.
  runVpnSyncs =
    run: syncs: stateFile:
    lib.concatMapStrings (sync: ''
      ${run}${sync} ${stateFile} "''${vpnExcludedPaths[@]}" \
        || printf '\033[1;33mwarning:\033[0m %s did not apply VPN app exclusion; is the VPN running?\n' ${sync} >&2
    '') syncs;

  # nix-darwin side of the macOS sync: the host's excludeFromVpn globals
  # whose resolved way is machine-wide ({ program, way } entries).
  darwinVpnSync =
    hostName: excluded:
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      syncs = config.hostConstants.vpn.syncExcludedApps;
      custom = lib.filter (g: g.way == "custom") excluded;
      casks = map (g: g.program) (lib.filter (g: g.way == "cask") excluded);
      brew = "sudo --user=${lib.escapeShellArg config.homebrew.user} --set-home ${config.homebrew.prefix}/bin/brew";
      # The cask's app bundle name; a renamed app carries its installed name as target.
      appName = ".casks[0].artifacts[] | .app? // empty | (.[1].target? // .[0])";
    in
    {
      system.activationScripts.postActivation.text = lib.mkIf (syncs != [ ]) (
        if custom != [ ] then
          throw "flake.programs.${(lib.head custom).program}: excludeFromVpn resolves to the \"custom\" way on ${hostName}, but macOS VPN exclusion supports \"cask\" and \"home\" installs only; install it as a cask or per-user, or drop excludeFromVpn"
        else
          ''
            ${addAppExecutable}
            ${lib.concatMapStrings (cask: ''
              app=$(${brew} info --cask --json=v2 ${cask} 2>/dev/null | ${lib.getExe pkgs.jq} -r '${appName}') || app=
              vpnAddAppExecutable "/Applications/$app" ${cask}
            '') casks}
            ${runVpnSyncs "" syncs "/var/db/vpn-excluded-apps"}
          ''
      );
    };

  # Home side of the macOS sync, in every baseline: excludeFromVpn home
  # installs collect their packages here.
  homeVpnSync =
    { config, lib, ... }:
    let
      syncs = config.hostConstants.vpn.syncExcludedApps;
    in
    {
      options.vpnExclusion.packages = lib.mkOption {
        type = types.listOf types.package;
        default = [ ];
        internal = true;
        description = "Packages of this home's excludeFromVpn programs, whose app executables the macOS sync excludes.";
      };

      config.home.activation.vpnExcludedApps = lib.mkIf (syncs != [ ]) (
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          ${addAppExecutable}
          ${lib.concatMapStrings (pkg: ''
            for bundle in ${pkg}/Applications/*.app; do
              vpnAddAppExecutable "$bundle" ${lib.getName pkg}
            done
          '') config.vpnExclusion.packages}
          ${runVpnSyncs "run " syncs "${config.xdg.stateHome}/vpn-excluded-apps"}
        ''
      );
    };

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

  generate =
    name: decl:
    let
      fail = message: throw "flake.programs.${name}: ${message}";
      suppressed = class: lib.elem class decl.handWritten;

      effective = lib.genAttrs platforms (platform: {
        install = installWays decl platform;
        systemConfig = lib.filter (m: m != null) [
          decl.${platform}.systemConfig
          decl.shared.systemConfig
        ];
        machineWide = lib.any (way: way != "home") (installWays decl platform);
      });

      homePlatforms = lib.filter (p: lib.elem "home" effective.${p}.install) platforms;
      hasHome = homePlatforms != [ ];
      hasMachineWide = lib.any (p: effective.${p}.machineWide) platforms;

      # A platform's packages: its block's, then shared's; pkgs.<name> when
      # no block sets any.
      setsPackages = block: decl.${block}.packages != null;
      packagesOf =
        platform: pkgs:
        if lib.any setsPackages (platforms ++ [ "shared" ]) then
          lib.concatMap (block: lib.optionals (setsPackages block) (decl.${block}.packages pkgs)) [
            platform
            "shared"
          ]
        else
          [ pkgs.${name} ];

      onPlatform =
        platform: pkgs:
        if platform == "linux" then pkgs.stdenv.hostPlatform.isLinux else pkgs.stdenv.hostPlatform.isDarwin;

      # Gate one platform module: its options stay declared everywhere, its
      # config applies only on the platform. Imports would escape the gate,
      # so a platform module may not make any.
      gateModule =
        platform: module:
        let
          gated =
            pkgs: m:
            if m ? imports then
              fail "imports a module inside ${platform}.config; move the import to shared.config"
            else if m ? config || m ? options then
              m // { config = lib.mkIf (onPlatform platform pkgs) (m.config or { }); }
            else
              { config = lib.mkIf (onPlatform platform pkgs) m; };
        in
        if builtins.isPath module then
          gateModule platform (import module)
        else
          lib.setFunctionArgs (
            args: gated args.pkgs (if lib.isFunction module then module args else module)
          ) (lib.optionalAttrs (lib.isFunction module) (lib.functionArgs module) // { pkgs = false; });

      # deferredModule merges every definition as { _file; imports = [ module ]; }
      # under one top-level imports list, so the gate wraps each definition's
      # module and keeps its location.
      gateBlock =
        platform:
        let
          block = decl.${platform}.config;
        in
        {
          imports = map (def: def // { imports = map (gateModule platform) def.imports; }) block.imports;
        };

      homeConfig = [ decl.shared.config ] ++ map gateBlock platforms;

      # The packages excludeFromVpn acts on, in the module system that
      # installs the program.
      vpnPackages =
        {
          config,
          options,
          pkgs,
          ...
        }:
        platform:
        lib.filter (pkg: pkg != null) (
          if lib.hasAttrByPath [ "programs" name "package" ] options then
            [ config.programs.${name}.package ]
          else if !decl.hasEnableOption then
            packagesOf platform pkgs
          else
            [ pkgs.${name} ]
        );

      # Higher-priority excluded copies, while the host has a VPN to exclude from.
      vpnWrappers =
        args@{ config, pkgs, ... }:
        platform:
        let
          commands = config.hostConstants.vpn.excludeCommands;
        in
        lib.optionals (decl.excludeFromVpn && commands != [ ]) (
          map (pkg: lib.hiPrio (vpnExcludedCopy pkgs commands pkg)) (vpnPackages args platform)
        );

      # The per-user install: platform-gated on content (imports are never
      # conditional) and hung off an overridable boolean, so a home install
      # always opts out with the uniform `programs.<name>.enable = false;`.
      installUnit =
        args@{
          pkgs,
          lib,
          config,
          ...
        }:
        let
          platform = if pkgs.stdenv.hostPlatform.isDarwin then "macos" else "linux";
        in
        {
          imports = homeConfig;

          options = lib.optionalAttrs (!decl.hasEnableOption) {
            programs.${name}.enable = lib.mkEnableOption name;
          };

          config = lib.mkIf (lib.elem platform homePlatforms) (
            lib.mkMerge [
              { programs.${name}.enable = true; }
              (lib.optionalAttrs (!decl.hasEnableOption) {
                # Plain: the boundary wrapper exempts lists, so this concatenates
                # with a user's own home.packages like an upstream HM module's.
                home.packages = lib.mkIf config.programs.${name}.enable (packagesOf platform pkgs);
              })
              (lib.optionalAttrs decl.excludeFromVpn (
                lib.mkIf config.programs.${name}.enable {
                  home.packages = vpnWrappers args platform;
                  vpnExclusion.packages = vpnPackages args platform;
                }
              ))
            ]
          );
        };

      # A platform's machine-wide unit: the generated install for its
      # named way, plus the effective systemConfig.
      systemUnit = platform: install: {
        imports = effective.${platform}.systemConfig;
        config = install;
      };

      units =
        lib.optionalAttrs (!suppressed "homeManager") {
          homeManager = {
            ${name} =
              if hasHome then
                installUnit
              else
                tombstone name "declares no per-user install way; import homeManager.${name}-config for the config alone, or add \"home\" to an install list";
            # Config only, carried plain — for users on machines where the
            # install is machine-wide.
            "${name}-config" = {
              imports = homeConfig;
            }
            // lib.optionalAttrs (decl.hasEnableOption && hasMachineWide) {
              # the host generator routes -config only alongside a machine-wide
              # install, so null the package: enabling then configures the
              # machine-installed app instead of double-installing the nix one
              programs.${name}.package = null;
            };
          };
        }
        // lib.optionalAttrs (!suppressed "nixos") {
          nixos.${name} =
            if effective.linux.machineWide then
              args@{ pkgs, ... }:
              systemUnit "linux" {
                environment.systemPackages =
                  lib.optional (lib.elem "system" effective.linux.install) pkgs.${name} ++ vpnWrappers args "linux";
              }
            else
              tombstone name "declares no Linux \"system\" or \"custom\" install way; import homeManager.${name}, or add one to linux.install";
        }
        // lib.optionalAttrs (!suppressed "darwin") {
          darwin.${name} =
            if effective.macos.machineWide then
              systemUnit "macos" {
                homebrew.casks = lib.optional (lib.elem "cask" effective.macos.install) name;
              }
            else
              tombstone name "declares no macOS \"cask\" or \"custom\" install way; import homeManager.${name}, or add one to macos.install";
        };

      # The first platform that breaks a per-platform rule, if any.
      firstPlatform = rule: lib.findFirst rule null platforms;
      customWithoutSystemConfig = firstPlatform (
        p: lib.elem "custom" effective.${p}.install && effective.${p}.systemConfig == [ ]
      );
      systemConfigWithoutWay = firstPlatform (
        p: effective.${p}.systemConfig != [ ] && !effective.${p}.machineWide
      );
    in
    # Incoherent declarations fail here, at declaration eval, before any
    # unit is imported anywhere.
    if !hasHome && !hasMachineWide then
      fail "declares no install way on any platform; set linux.install, macos.install, or shared.install, or delete the declaration"
    else if customWithoutSystemConfig != null then
      fail "declares the \"custom\" install way on ${customWithoutSystemConfig} without a systemConfig to install it; set ${customWithoutSystemConfig}.systemConfig or shared.systemConfig, or drop the way"
    else if systemConfigWithoutWay != null then
      fail "sets a systemConfig on ${systemConfigWithoutWay}, which declares no machine-wide install way; add \"${
        if systemConfigWithoutWay == "linux" then "system" else "cask"
      }\" or \"custom\" to ${systemConfigWithoutWay}.install, or drop the systemConfig"
    else if hasHome && suppressed "homeManager" then
      fail "declares a per-user (\"home\") install way but marks homeManager hand-written; drop the way or the handWritten entry"
    else if effective.linux.machineWide && suppressed "nixos" then
      fail "declares a Linux machine-wide install way but marks nixos hand-written; drop the way or the handWritten entry"
    else if effective.macos.machineWide && suppressed "darwin" then
      fail "declares a macOS machine-wide install way but marks darwin hand-written; drop the way or the handWritten entry"
    else
      units;
in
{
  # One structured declaration per program, living in that program's
  # feature folder; the generator turns each into importable
  # flake.modules units — one per declared install way, plus the plain
  # -config unit. Flake-level machinery beside the dendritic tree, not a
  # feature module itself.

  options.flake.programs = lib.mkOption {
    type = types.attrsOf programType;
    default = { };
    description = "Program declarations, each generating flake.modules units.";
  };

  config.flake = {
    modules = lib.mkMerge (lib.mapAttrsToList generate config.flake.programs);
    # The host and user generators resolve ways in the same combined order.
    lib = {
      inherit installWays;
      # The hosts generator adds these to darwin hosts and every baseline.
      vpnSync = {
        darwin = darwinVpnSync;
        homeManager = homeVpnSync;
      };
    };
  };
}
