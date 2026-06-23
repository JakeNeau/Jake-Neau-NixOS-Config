# Running `nr` / `nrr`

I may run the `nr` and `nrr` rebuild functions — but **only after confirming the
specific run with you, every time.** Propose it, get an explicit yes, then run.
This is the standing "explicit ask" the project `CLAUDE.md` requires before these
run: it gates each run behind a confirmation, it never waives one. Never run
either just to check something.

## Why each run is gated

`nr` pulls, updates every flake input, verifies every environment builds, then
**commits and pushes (sometimes `--force-with-lease`) to the public GitHub repo
and rebuilds the system** — outward-facing and effectively irreversible. `nrr` is
just `nr "Regular update"`, so it carries the same weight.

## How to run them

They are fish autoloaded functions, absent from my zsh shell, so invoke them as
`fish -c 'nrr'` or `fish -c 'nr "<message>"'`. They need the real network, `sudo`,
and git push, so they run with `dangerouslyDisableSandbox: true`. The
`permissions.ask` rule in `settings.json` forces a harness prompt as a backstop.
See [[skill:machine-layout]] for how a rebuild is applied.
