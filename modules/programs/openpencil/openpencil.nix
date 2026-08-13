{...}: let
  version = "0.14.0";
  mkOpenPencilTools = pkgs:
    pkgs.buildNpmPackage {
      pname = "openpencil-tools";
      inherit version;
      src = ./npm;
      npmDepsHash = "sha256-WbwkB76bG0Gz4fMopTrsVObAjgNUoGfOdmFgXiDR5b8=";
      dontNpmBuild = true;
    };
  mkOpenPencilApp = pkgs:
    if pkgs.stdenv.hostPlatform.isDarwin
    then
      pkgs.stdenvNoCC.mkDerivation {
        pname = "openpencil";
        inherit version;
        src = pkgs.fetchurl {
          url = "https://github.com/open-pencil/open-pencil/releases/download/v${version}/OpenPencil_aarch64.app.tar.gz";
          hash = "sha256-SfNo7MfC0yA8VqSGNf+KMBFC9h9KurDb/o0ltrmz2Ec=";
        };
        sourceRoot = ".";
        installPhase = ''
          runHook preInstall
          mkdir -p "$out/Applications"
          cp -R OpenPencil.app "$out/Applications/"
          runHook postInstall
        '';
      }
    else
      pkgs.appimageTools.wrapType2 {
        pname = "openpencil";
        inherit version;
        src = pkgs.fetchurl {
          url = "https://github.com/open-pencil/open-pencil/releases/download/v${version}/OpenPencil_${version}_amd64.AppImage";
          hash = "sha256-UpgOigckZL5945LHGdaGy9CJ06zZbQjp3O/gmFV8UJ0=";
        };
      };
in {
  flake.programs.openpencil = {
    install.linux = ["home"];
    install.macos = ["home"];
    hasEnableOption = false;
    packages = pkgs: [
      (mkOpenPencilApp pkgs)
      (mkOpenPencilTools pkgs)
    ];
  };
}
