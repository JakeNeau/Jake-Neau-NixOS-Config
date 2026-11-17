{
  # ==========================================================================
  # TEST: kenning trial. REMOVE THIS FILE WHEN THE TRIAL ENDS.
  # ==========================================================================
  # Loads the kenning trial skills and role agents into Claude Code, for
  # jake.neau on cedar only. Each entry is an out-of-store symlink into the
  # kenning checkout, so an edit there needs no rebuild. This is the one place
  # where Claude Code loads a skill from outside config/skills. To end the
  # trial, delete this file and run `hr`.
  flake.programs.kenning-trial = {
    shared.install = [ "home" ];
    hasEnableOption = false;
    # Config only: without this the generated toggle would install pkgs.kenning-trial.
    shared.packages = _: [ ];
    shared.config =
      { config, lib, ... }:
      let
        link = path: {
          source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/kenning/${path}";
        };
        skills = [
          "kenning-read"
          "kenning-write"
          "probe"
          "explain-claim"
          "map"
          "teach-plan"
          "explain"
          "review"
        ];
        agents = [
          "kenning-drafter"
          "kenning-adversary"
          "kenning-planner"
        ];
      in
      {
        home.file =
          lib.genAttrs' skills (name: lib.nameValuePair ".claude/skills/${name}" (link "skills/${name}"))
          // lib.genAttrs' agents (
            name: lib.nameValuePair ".claude/agents/${name}.md" (link "agents/${name}.md")
          );
      };
  };

  flake.users."jake.neau".hosts.cedar.programs = [ "kenning-trial" ];
}
