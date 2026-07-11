# oh-my-pi migration — overview

Replace Claude Code with **oh-my-pi (omp)** — <https://github.com/can1357/oh-my-pi>,
Can Bölük's batteries-included fork of Mario Zechner's `pi` coding agent — on every
machine except cedar. Cedar keeps Claude Code unchanged.

This is the overview of a large spec; the sub-specs carry the detail:

- [`packaging.md`](packaging.md) — the flake input, the program declarations, and
  the per-user routing that performs the swap.
- [`omp-config.md`](omp-config.md) — the declarative native omp config module
  (`~/.omp/agent/`), including the superpowers plugin.
- [`nvim-integration.md`](nvim-integration.md) — codecompanion.nvim via ACP, the
  three-way AI-plugin conditional in nvf, and the localAI removal + shortcut ports.

## Spec

### The decision

omp replaces Claude Code everywhere but cedar. The setup here centers on workflow
machinery — subagents with verification loops, MCP servers, mirrored LSP servers,
skills — and omp preserves all of it natively: a subagents/task tool, MCP support,
built-in LSP/DAP, skills, plan mode, a Claude-plugin-compatible marketplace, and
Anthropic Pro/Max subscription OAuth. Vanilla `pi` deliberately omits subagents
and MCP, and opencode would mean rebuilding the machinery from scratch; omp was
chosen over both explicitly.

**Accepted risk:** omp is a fast-moving single-maintainer fork (~18-hour release
cadence). Mitigations:

- the version is pinned via `flake.lock`, so it moves only on deliberate `nr`
  updates;
- cedar's Claude Code setup stays untouched as a working fallback;
- rollback is flipping one user declaration back (see routing below).

### The structural insight: a pure per-user swap

cedar is the only host with user `jake.neau`; redwood, spruce, and aspen have only
user `jakeneau`. So "every machine except cedar" is exactly "user `jakeneau` gets
omp, user `jake.neau` keeps Claude Code" — the swap is pure per-user routing
through `flake.users` declarations, with **no host conditionals anywhere**.

Routing summary (detail in [`packaging.md`](packaging.md)):

| user | hosts | agent | delivered by |
|---|---|---|---|
| `jakeneau` | redwood, spruce, aspen | oh-my-pi | `flake.users.jakeneau.programs = ["oh-my-pi"]` |
| `jake.neau` | cedar | claude-code | `flake.users."jake.neau".programs = ["claude-code"]` |

The `claude-code` import leaves the `role-desktop` homeManager aggregate as part
of the same change, so nothing is double-delivered.

### Native config format, explicitly

omp config is written in **omp's native format** — the `.omp` project root and
`~/.omp/agent/` global directory — never the `.claude`/compat discovery providers.
Those compat providers remain as an untouched safety net only (native discovery
priority is 100 vs claude's 80, so native always wins where both exist).

### Interaction with the feature-unification spec

`specs/feature-unification.md` (pending) renames `flake.programs` to
`flake.features`. This spec is written against today's `flake.programs` schema
(`modules/nix/flake-parts/declarations/programs.nix`); if feature-unification
lands first, the declaration names here shift mechanically with it — nothing else
in this spec depends on the rename.

## Plan

Implementation runs through code-writer per the standing flow, **one sub-spec at a
time, in order**: packaging → omp-config → nvim-integration. Each sub-spec's
Tasks are its own commit points; each stage leaves the flake dry-buildable (the
oh-my-pi declaration lands with its config module in the same stage pair, but
packaging's routing tasks are sequenced so no home ever references a missing
unit — see the sub-specs).

Validation at every stage (repo `AGENTS.md` / nix-config skill):

- `nix flake check`
- the three jakeneau homes by activationPackage drvPath eval — never full-built
  during implementation, since the numtide cache is inactive until each
  machine's next `nr` (see [`packaging.md`](packaging.md))
- cedar's home and both darwin hosts by `nix build --no-link`
- NixOS hosts by drvPath eval on this Mac
  (`nix eval .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath`)
- `git add` new files before building — flake eval ignores untracked files.

### Per-machine user actions after `hr` (imperative, one-time)

On each omp machine (redwood, spruce, aspen), the system rebuild (`nr`) must
come **before** the user's home activation builds omp: the numtide substituter
config lands system-side (`nix.settings`), so an `hr`/home build before the
first post-change `nr` would compile omp's Rust core from source. Then:

1. `/login` in omp — Anthropic subscription OAuth; tokens live in `agent.db`
   under `~/.omp/agent/`, never in Nix.
2. `omp plugin marketplace add anthropics/claude-plugins-official`, then
   `omp plugin install superpowers@claude-plugins-official` — same
   declared-intent + one-time-imperative hybrid as the existing Claude plugin
   pattern.

### Rollback

Flip the user declaration: remove `"oh-my-pi"` from `flake.users.jakeneau.programs`
and put `"claude-code"` there instead. Cedar is never touched.

### Docs graduation (at spec retirement)

Per the transient spec lifecycle, when the sub-specs are implemented:

- a reference page for the oh-my-pi program (what the module manages);
- the feature index entry for `modules/programs/oh-my-pi/`;
- the decision rationale (why omp, the per-user routing insight, the accepted
  fork risk) into the explanation docs;
- updates wherever the docs currently describe claude-code as delivered by
  role-desktop.

## Tasks

1. Implement [`packaging.md`](packaging.md).
2. Implement [`omp-config.md`](omp-config.md).
3. Implement [`nvim-integration.md`](nvim-integration.md).
4. User performs the per-machine actions above after rebuilding each home.
5. Graduate the rationale into the docs and delete this spec folder.
