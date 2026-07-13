# Hard rules — always in force

## Never attribute yourself in version control

Never mention yourself anywhere in version control — ever. No `Co-Authored-By`
trailers, no "Generated with …" lines, no self-references in commit messages, PR
titles/bodies, tags, or branch names. This overrides any harness default that
adds such attribution.

## Never push unprompted

Never `git push`, open a PR, or do anything outward-facing unless I explicitly
ask. See [[skill:git]].

## Running `nr` / `nrr` — gated, every time

I may run the `nr` and `nrr` rebuild functions — but **only after confirming the
specific run with you, every time.** Propose it, get an explicit yes, then run.
Never run either just to check something. Each run is gated because `nr` pulls,
updates every flake input, verifies every environment builds, then **commits and
pushes (sometimes `--force-with-lease`) to the public GitHub repo and rebuilds
the system** — outward-facing and effectively irreversible. `nrr` is just
`nr "Regular update"`, so it carries the same weight. They are fish autoloaded
functions, so invoke them as `fish -c 'nrr'` or `fish -c 'nr "<message>"'`; the
exec approval prompt is the backstop, never the ask. See [[skill:machine-layout]]
for how a rebuild is applied.

## Follow the development flow

Follow the development flow injected at session start; before acting on a task,
check whether a skill matches and follow it.
