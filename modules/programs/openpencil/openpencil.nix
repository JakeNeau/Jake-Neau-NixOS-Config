{ ... }:
let
  version = "0.16.0";
in
{
  flake.programs.openpencil = {
    shared.install = [ "home" ];
    hasEnableOption = false;

    linux.packages = pkgs: [
      (pkgs.appimageTools.wrapType2 {
        pname = "openpencil";
        inherit version;
        src = pkgs.fetchurl {
          url = "https://github.com/open-pencil/open-pencil/releases/download/v${version}/OpenPencil_${version}_amd64.AppImage";
          hash = "sha256-p9iTrDU2fI6gALAIkBNs5YYaE78ldLRHYPd4Sc/fd6I=";
        };
      })
    ];

    macos.packages = pkgs: [
      (pkgs.stdenvNoCC.mkDerivation {
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
      })
    ];

    shared.packages = pkgs: [
      (pkgs.buildNpmPackage {
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
      })
    ];
  };
}
