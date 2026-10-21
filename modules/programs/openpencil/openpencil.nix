{ ... }:
let
  version = "0.16.0";
  mkOpenPencilTools =
    pkgs:
    pkgs.buildNpmPackage {
      pname = "openpencil-tools";
      inherit version;
      src = ./npm;
      npmDepsHash = "sha256-Sy5Zx0hq6iFZwDbGD8P9Aaw0ckwz47MBk1GABjSg9II=";
      dontNpmBuild = true;
      # buildNpmPackage links only this wrapper's own bins, not its dependencies'.
      postInstall = ''
        mkdir -p "$out/bin"
        for command in openpencil-mcp openpencil-mcp-http; do
          ln -s "$out/lib/node_modules/openpencil-tools/node_modules/.bin/$command" "$out/bin/$command"
        done
      '';
    };
  mkOpenPencilApp =
    pkgs:
    if pkgs.stdenv.hostPlatform.isDarwin then
      pkgs.stdenvNoCC.mkDerivation {
        pname = "openpencil";
        inherit version;
        src = pkgs.fetchurl {
          url = "https://github.com/open-pencil/open-pencil/releases/download/v${version}/OpenPencil_aarch64.app.tar.gz";
          hash = "sha256-MdP8W93nrP+lBuBjJj0qG8uRP0Bd3vR9QFdCUU7mVSc=";
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
          hash = "sha256-p9iTrDU2fI6gALAIkBNs5YYaE78ldLRHYPd4Sc/fd6I=";
        };
      };
in
{
  flake.programs.openpencil = {
    install.linux = [ "home" ];
    install.macos = [ "home" ];
    hasEnableOption = false;
    packages = pkgs: [
      (mkOpenPencilApp pkgs)
      (mkOpenPencilTools pkgs)
    ];
  };
}
