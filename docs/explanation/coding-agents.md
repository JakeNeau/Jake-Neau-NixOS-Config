# Coding agents: pi and claude-code, routed per user

Which coding agent runs where, and why the routing is per user. On every
machine except cedar the agent is **`pi`** — Mario Zechner's minimal coding
agent — with focused declarative extensions. cedar keeps **Claude Code**.
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

## pi, with focused extensions

The pi module keeps upstream pi small while declaratively adding a research
stack and typed-link navigation:

- **pi-web-access** performs structured search and source extraction.
- **pi-agent-browser-native** drives a real browser only when static retrieval
  cannot handle JavaScript or interaction.
- **typed-links** resolves shared skills and project resources on demand without
  placing their bodies in the startup context.
- **the writing system** routes prose through controlled form and substantive
  structure policies. See [Pi's writing system](pi-writing-system.md) for its
  design.

Search is deliberately owned by one extension; the browser extension's
companion search tool is disabled. Browser-cookie extraction is also disabled,
and unattended search returns raw evidence to the main agent instead of opening
an interactive curator or invoking a second summarizing model. Pi's mutable
settings, auth, models, and sessions remain user-owned. See
[the pi reference](../reference/pi.md).

This remains intentionally narrower than the former **oh-my-pi (omp)** setup,
which carried a full config tree of subagents, MCP servers, hooks, and skills.
The upstream agent now has the focused capabilities needed for evidence-backed
research and progressively disclosed guidance; broader configuration can still
be added incrementally when earned.

## Editor integration

Which in-editor AI plugin a home gets follows the same no-host-conditionals
principle: the nvf module (`modules/programs/nvf/nvf.nix`) branches on the
*sibling program state in the same home*, read `attrByPath`-style since the
enable option only exists where the generated unit is imported.

- **claude-code homes** get **claudecode.nvim**, spawning the `claude` CLI.
- **pi homes** get **codecompanion.nvim** over ACP. The `pi-acp` process
  translates CodeCompanion's standard ACP transport to Pi's native RPC mode,
  so the editor uses the same Pi binary, extensions, authentication, and
  persistent sessions as the terminal.

## Removed along the way

- **The local-inference stack** — the `llama-server` service, the `local-ai`
  role, and the `hostConstants.localAi` fact — was removed during the earlier
  omp migration and did not return.
- **FIM (fill-in-the-middle) ghost-text autocomplete is gone everywhere**,
  with no replacement — nothing in the current stack offers inline completion.
- **The `<leader>ak`/`aq`/`ah` explain/ask/how shortcuts are gone.** They
  briefly lived as codecompanion prompt-library entries on omp homes; with
  codecompanion removed, no home has them.
