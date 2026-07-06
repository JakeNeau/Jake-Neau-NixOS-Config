# TODO

- [ ] Remove the darwin manual workaround once nix-darwin#1819 is merged and
      flake inputs move past it: delete `modules/system/manual-workaround/` and
      its `manual-workaround` import line in
      `modules/system/types/system-default/system-default.nix`.
- [ ] When next touching `CLAUDE.md` (lines 70-72): the `nr`/`nrr` caution says
      the flow unconditionally runs `git add -A`, which under-describes the new
      `nr -s`/`--staged` flag (stages only `flake.lock` and stashes unstaged
      tracked changes; see `modules/programs/fish/functions/nr.fish`). Update
      the sentence to cover both modes. Low priority.
- [ ] When next working `specs/declaration-framework.md` (lines 728 and 1107):
      its citations of `nr.fish:55-75` are stale — the `-s`/`--staged` change
      shifted `modules/programs/fish/functions/nr.fish` by ~26 lines. Refresh
      the line numbers or make the citations line-number-free. Low priority.
