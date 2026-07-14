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
`fish -c 'nrr'`, `fish -c 'nr "<message>"'`, or
`fish -c 'nr "<message>" -l "<body>"'`. They need the real network, `sudo`,
and git push, so they run with `dangerouslyDisableSandbox: true`. The
`permissions.ask` rule in `settings.json` forces a harness prompt as a backstop.
See [[skill:machine-layout]] for how a rebuild is applied.

## Commit message guidance

Keep `<message>` at 50 characters or fewer — `nr` prepends a
`<host> Generation <NNN>: ` prefix (roughly 22 characters, depending on the
host name), which keeps the full git subject near the conventional 72-character
limit. If 50 characters says everything, use the short message alone. Reach for
`-l`/`--long "<body>"` only when the change genuinely warrants explanation
beyond the subject, and write the body in complete sentences.
