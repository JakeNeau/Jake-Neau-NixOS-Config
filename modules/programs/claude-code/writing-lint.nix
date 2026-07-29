{
  # Linter for the mechanical subset of the controlled-English form policy in
  # ./config/skills/controlled-writing, which names this command.
  perSystem = {pkgs, ...}: let
    # writePython3Bin runs flake8 at build time, so a style regression in the
    # linter fails the build instead of shipping.
    claude-writing-lint = pkgs.writers.writePython3Bin "claude-writing-lint" {} (
      builtins.readFile ./writing/writing_lint.py
    );
  in {
    packages.claude-writing-lint = claude-writing-lint;

    checks.claude-writing-lint =
      pkgs.runCommand "claude-writing-lint" {
        nativeBuildInputs = [pkgs.python3];
      } ''
        cp -R ${./writing} writing
        chmod -R u+w writing
        PYTHONPATH=writing python3 -m unittest discover -s writing/tests -v
        # smoke lint through the built binary, so packaging is proven too
        printf 'The parser reads the file.\n' | ${claude-writing-lint}/bin/claude-writing-lint
        touch "$out"
      '';
  };
}
