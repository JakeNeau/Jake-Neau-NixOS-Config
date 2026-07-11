# Coding agents: why oh-my-pi, and why per user

Why **oh-my-pi (omp)** — [Can Bölük's fork](https://github.com/can1357/oh-my-pi)
of Mario Zechner's `pi` coding agent — replaced Claude Code on every machine
except cedar, and the design choices around the swap. What the modules
concretely manage: [the oh-my-pi reference](../reference/oh-my-pi.md), [the
claude-code subsystem](claude-code-config.md).

## Why omp over vanilla pi or opencode

The agent setup here centers on workflow machinery — subagents with
verification loops, MCP servers, mirrored LSP servers, skills — and omp
preserves all of it natively: a subagents/task tool, MCP support, built-in
LSP/DAP, skills, plan mode, a Claude-plugin-compatible marketplace, and
Anthropic Pro/Max subscription OAuth. Vanilla `pi` deliberately omits
subagents and MCP; opencode would have meant rebuilding the machinery from
scratch. omp was chosen over both explicitly.

**Accepted risk:** omp is a fast-moving single-maintainer fork (~18-hour
release cadence). Mitigations:

- the version is pinned via `flake.lock`, so it moves only on deliberate
  update runs;
- cedar's Claude Code setup stays untouched as a working fallback;
- rollback is flipping one user declaration back (below).

## The structural insight: a pure per-user swap

cedar is the only host with user `jake.neau`; redwood, spruce, and aspen have
only user `jakeneau`. So "every machine except cedar" is exactly "user
`jakeneau` gets omp, user `jake.neau` keeps claude-code" — the swap is pure
per-user routing through `flake.users` declarations, with **no host
conditionals anywhere**:

| user | hosts | agent | delivered by |
|---|---|---|---|
| `jakeneau` | redwood, spruce, aspen | oh-my-pi | `flake.users.jakeneau.programs = ["oh-my-pi"]` |
| `jake.neau` | cedar | claude-code | `flake.users."jake.neau".programs = ["claude-code"]` |

To make the routing uniform, claude-code — previously a hand-written aspect
delivered through the `role-desktop` homeManager aggregate — was converted
into a `flake.programs.claude-code` declaration carrying the same config
module, so both agents ride the same declaration channel
([add a per-user program](../how-to/add-a-per-user-program.md)). Rollback is
the same one-line mechanism: swap `"oh-my-pi"` for `"claude-code"` in
`flake.users.jakeneau.programs`; cedar is never touched.

## Native config format, deliberately

omp config is written in **omp's native format** — the `~/.omp/agent/`
directory — never the `.claude`-compat discovery providers omp also supports.
Native discovery priority is 100 versus the claude provider's 80, so the
native tree always wins where both exist; the compat providers remain as an
untouched safety net only.

## The shared-skills split

Skills that are agent-agnostic — comments, diataxis, git, jujutsu,
machine-layout, specs, starting-a-project, using-skills, writing-skills —
live once in `modules/programs/agents-shared/skills/` and are inlined by
*both* agent modules, so no skill text is duplicated and an edit reaches both
harnesses. Skills about Claude Code's own machinery (its config subsystem,
hooks, plugins, ...) stay in the claude-code module; each module merges the
shared set with its own local set at read time.

## Editor integration: codecompanion over ACP

omp homes get **codecompanion.nvim** talking to omp over ACP (the Agent
Client Protocol), via an adapter running `omp acp`
(`modules/programs/nvf/nvf.nix`). ACP was chosen because it inverts the
auth/permission problem: omp owns authentication (tokens in its own
`agent.db`) so nvim holds no API key, and edits route through ACP's
`session/request_permission` rather than the plugin writing buffers freely.

Which AI plugin a home gets follows the same no-host-conditionals principle:
the nvf module branches on the *sibling program state in the same home*
(whether the home enables oh-my-pi or claude-code, read attrByPath-style
since the options only exist where the generated units are imported) —
oh-my-pi wins if somehow both are enabled, then claude-code (keeping
claudecode.nvim exactly as before), else no AI plugin at all.

## The localAI removal

The migration also removed the local-inference stack — the `llama-server`
service, the `local-ai` role, and the `hostConstants.localAi` fact — because
the full omp agent supersedes what the small local model was for: the
explain/ask shortcuts (`<leader>ak`/`aq`/`ah`) were ported to codecompanion
prompt-library entries, upgraded from a 512-token local completion model to
an agent that can read and grep the actual config source.

Accepted consequences, recorded deliberately:

- **FIM (fill-in-the-middle) ghost-text autocomplete is gone everywhere**,
  with no replacement — nothing in the new stack offers inline completion.
- **cedar loses `<leader>ak`/`aq`/`ah` entirely** — the ports target
  codecompanion (omp) homes only, and cedar keeps claudecode.nvim, which has
  no equivalent prompt-library mechanism wired here.
