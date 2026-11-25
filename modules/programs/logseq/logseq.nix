{
  # home-manager has no programs.logseq module, so the generator supplies the toggle
  flake.programs.logseq = {
    shared.install = [ "home" ];
    hasEnableOption = false;
    shared.packages = pkgs: [
      # no supported Electron compiles Logseq's better-sqlite3, so permit the EOL electron_39 for Logseq alone
      # fails to evaluate once nixpkgs drops the electron_39 argument; delete the override then
      (pkgs.logseq.override {
        electron_39 = pkgs.electron_39.overrideAttrs (old: {
          meta = old.meta // {
            knownVulnerabilities = [ ];
          };
        });
      })
    ];
  };
}
