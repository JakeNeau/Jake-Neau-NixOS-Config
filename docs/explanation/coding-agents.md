# Coding agents: pi and claude-code, routed per user

Which coding agent runs where, and why the routing is per user. On every
machine except cedar the agent is **`pi`** — Mario Zechner's minimal coding
agent — installed **bare** (just the binary). cedar keeps **Claude Code**.
What the modules concretely manage: [the pi reference](../reference/pi.md),
[the claude-code subsystem](claude-code-config.md).

## The structural insight: a pure per-user swap

cedar is the only host with user `jake.neau`; redwood, spruce, and aspen have
only user `jakeneau`. So "every machine except cedar" is exactly "user
`jakeneau` gets pi, user `jake.neau` keeps claude-code" — the choice is pure
per-user routing through `flake.users` declarations, with **no host
conditionals anywhere**:

| user | hosts | agent | delivered by |
|---|---|---|---|
| `jakeneau` | redwood, spruce, aspen | pi | `flake.users.jakeneau.programs = ["pi"]` |
| `jake.neau` | cedar | claude-code | `flake.users."jake.neau".programs = ["claude-code"]` |

Both agents ride the same declaration channel: claude-code was converted from
a hand-written aspect into a `flake.programs.claude-code` declaration so that
swapping agents is a one-line change to a user's `programs` list
([add a per-user program](../how-to/declarations/add-a-per-user-program.md)).

## pi, with focused web access

The pi module keeps upstream pi small while declaratively adding one coherent
research stack:

- **pi-web-access** performs structured search and source extraction.
- **pi-agent-browser-native** drives a real browser only when static retrieval
  cannot handle JavaScript or interaction.

Search is deliberately owned by one extension; the browser extension's
companion search tool is disabled. Browser-cookie extraction is also disabled,
and unattended search returns raw evidence to the main agent instead of opening
an interactive curator or invoking a second summarizing model. Pi's mutable
settings, auth, models, and sessions remain user-owned. See
[the pi reference](../reference/pi.md).

This remains intentionally narrower than the former **oh-my-pi (omp)** setup,
which carried a full config tree of subagents, MCP servers, hooks, and skills.
The upstream agent now has only the web capabilities needed for evidence-backed
research; broader configuration can still be added incrementally when earned.

## Editor integration

Which in-editor AI plugin a home gets follows the same no-host-conditionals
principle: the nvf module (`modules/programs/nvf/nvf.nix`) branches on the
*sibling program state in the same home*, read `attrByPath`-style since the
enable option only exists where the generated unit is imported.

- **claude-code homes** get **claudecode.nvim**, spawning the `claude` CLI.
- **pi homes** get **no in-editor AI plugin**. The previous omp integration —
  codecompanion.nvim driving omp over ACP (the Agent Client Protocol) — was
  removed because upstream pi has no ACP subcommand for codecompanion to drive.
  Restoring pi's in-editor integration via pi extensions is tracked in
  `TODO.md`.

## Removed along the way

- **The local-inference stack** — the `llama-server` service, the `local-ai`
  role, and the `hostConstants.localAi` fact — was removed during the earlier
  omp migration and did not return.
- **FIM (fill-in-the-middle) ghost-text autocomplete is gone everywhere**,
  with no replacement — nothing in the current stack offers inline completion.
- **The `<leader>ak`/`aq`/`ah` explain/ask/how shortcuts are gone.** They
  briefly lived as codecompanion prompt-library entries on omp homes; with
  codecompanion removed, no home has them.
