# oh-my-pi declarative config

Sub-spec of [`omp-migration.md`](omp-migration.md): the home-manager config module
carried by the `flake.programs.oh-my-pi` declaration, rendering `~/.omp/agent/`
declaratively in **omp's native format** (never the `.claude` compat providers —
those stay as an untouched safety net; native discovery priority 100 beats
claude's 80).

The claude-code module (`modules/programs/claude-code/claude-code.nix`) is the
pattern source throughout: its `readMarkdown`/`readSkills` helpers, its
settings-policy activation merge, and its `home.file` usage. The omp module
mirrors those idioms; source files live in `modules/programs/oh-my-pi/config/`
except the shared skills (below).

## Spec

Everything the Claude setup manages declaratively gets a native omp counterpart:

| Claude Code | omp native |
|---|---|
| `~/.claude/CLAUDE.md` (context) | `~/.omp/agent/AGENTS.md` |
| `~/.claude/rules/*.md` | `~/.omp/agent/RULES.md` (sticky rules) |
| `~/.claude/skills/<n>/SKILL.md` | `~/.omp/agent/skills/<n>/SKILL.md` |
| `~/.claude/agents/*.md` | `~/.omp/agent/agents/<n>.md` (task agents) |
| MCP via `programs.mcp` + integration | `~/.omp/agent/mcp.json` |
| `settings.json` policy merge (jq) | `config.yml` policy merge (yq) |
| plugins via settingsPolicy + one-time install | omp marketplace, one-time install |

Deliberately dropped, with rationale:

- **The 7 gate hooks** (`config/hooks/` in the claude-code module) — that
  discipline moves into RULES.md and the agent definitions; omp's TypeScript
  hooks are documented as a follow-up if instructions alone prove too soft.
- **agents-md-context hook** — omp discovers a repo-root `AGENTS.md` natively,
  walk-up included.
- **lspServers block** — omp has LSP built in.
- **sandbox settings** — omp's approval mode covers this instead.
- **statusline + keybindings.json** — omp brings its own TUI.
- **commands/** — empty today; nothing to port.

Auth is imperative by design: `/login` once per machine; tokens live in
`agent.db` under `~/.omp/agent/`, never in Nix. (`PI_CODING_AGENT_DIR` relocates
the base directory if ever needed.)

## Plan

### `~/.omp/agent/AGENTS.md` — global context

Via `home.file`, from `config/AGENTS.md` in the module folder. Content: the
durable essence of the current `config/CLAUDE.md`, rewritten tool-agnostically —
simple-and-elegant above all, the comment style, explain-then-prove changes,
liberal internet use, docs-first/Diátaxis. The **Superpowers flow language is
kept** (superpowers rides along via the marketplace, below). Claude-plugin and
hook-gate mechanics are dropped.

### `~/.omp/agent/RULES.md` — sticky rules

Via `home.file`, from `config/RULES.md`. omp re-injects a top-level RULES.md near
the current turn, so it survives long conversations — the right home for the
short hard constraints:

- the nr/nrr confirmation gate (from `config/rules/nr-nrr.md`);
- never self-attribute in version control;
- never push unprompted;
- the adapted superpowers-precedence rule (from
  `config/rules/superpowers-precedence.md`; hook-gate/plugin mechanics out, the
  flow and agent-roster references stay).

### `~/.omp/agent/skills/` — shared portable skills

A **new shared source directory** consumed by both the claude-code and oh-my-pi
config modules, so no skill text is duplicated. Suggested location:
`modules/programs/agents-shared/skills/` (**plan item:** settle the exact
location to fit repo idioms — it holds no `.nix` files, so import-tree ignores
it, same as the existing `config/` trees).

- **Portable set (moves to the shared dir):** comments, diataxis, git, jujutsu,
  machine-layout, specs, starting-a-project, using-skills, writing-skills — the
  last two rewritten tool-agnostically where they reference Claude machinery, so
  one text serves both harnesses. Beyond those two, sweep **all nine** for
  `[[skill:...]]` links into the claude-only set and for references to
  Claude-specific machinery (known instance: machine-layout links
  `[[skill:claude-code-config]]`), adjusting or dropping each so the shared
  text stands alone in both harnesses.
- **Claude-only set (stays in the claude-code module):** claude-code-config,
  configuring-lsp-servers, configuring-mcp-servers, configuring-plugins,
  writing-agents, writing-claude-md, writing-commands, writing-hooks,
  writing-rules.

Both modules read the shared dir with a `readSkills`-shaped helper. The helper
keeps its one-directory shape; each call site merges two invocations (e.g.
`readSkills sharedDir // readSkills localDir`). The omp module writes
`home.file.".omp/agent/skills/<n>/SKILL.md"` entries from the same reader.

### `~/.omp/agent/agents/` — the subagent roster

Port the claude-code agent definitions (`config/agents/*.md`, 18 files) as omp
task-agent definitions. omp agent frontmatter: `name`, `description`, the system
prompt as the body, and optionally `tools` (CSV/array; `yield` is auto-added),
`spawns`, `model`, `thinkingLevel`, `output` (schema), `blocking`,
`autoloadSkills`, `readSummarize`.

omp bundles scout/designer/reviewer/librarian/task/sonic agents — lean on them
where they overlap (e.g. scout ≈ this repo's Explore usage) rather than porting
redundant definitions.

**First pass ports the load-bearing ten:** code-writer, code-reviewer,
plan-verifier, codebase-investigator, bug-finder, test-writer, test-verifier,
web-researcher, comment-writer, comment-style-enforcer. The remaining eight
(doc-reader, doc-reviewer, doc-writer, spec-reader, spec-writer, git-vcs,
jujutsu-vcs, todo-writer) are deferred follow-up work (tracked in TODO.md).

**Plan item:** per-agent tool-name adaptation — the Claude tool names
(Read/Grep/Glob/Write/Edit/Bash/Agent) map onto omp's (read, write, edit, bash,
task, …); settle the mapping once and apply it across the ported frontmatter.

### `~/.omp/agent/mcp.json`

Declarative `home.file` JSON carrying the `nixos` server, matching the existing
`programs.mcp.servers.nixos` wiring (command pinned to the Nix store path of
`pkgs.mcp-nixos` via `lib.getExe`):

```json
{
  "$schema": "https://raw.githubusercontent.com/can1357/oh-my-pi/main/packages/coding-agent/src/config/mcp-schema.json",
  "mcpServers": { "nixos": { "command": "<store path>" } }
}
```

### `~/.omp/agent/config.yml` — policy merge, not a symlink

omp rewrites `config.yml` at runtime (`/settings`, `omp config set`), exactly as
Claude Code rewrites `settings.json` — so it is **not** managed as a read-only
store symlink. Instead, deep-merge a policy attrset at `home.activation` time
with `pkgs.yq-go`, pattern-matching the existing
`home.activation.claudeCodeSettingsPolicy` jq merge. The mechanism differs in
one spot: jq's `--argjson` has no yq-go equivalent, so materialize the policy
attrset as a JSON file in the store (JSON is valid YAML) and merge with

```
yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' <existing> <policy>
```

into a temp file — create-if-missing, move into place; policy keys win, the
same semantics as the jq merge.

Policy content:

- Anthropic as the default provider (subscription OAuth);
- theme;
- a conservative **approval mode** — omp is YOLO-by-default; **plan item:** pick
  the exact mode from omp's `docs/approval-mode.md`.

### Superpowers via the marketplace

Same declared-intent + one-time-imperative hybrid as the existing Claude plugin
pattern (see the repo's configuring-plugins skill): omp's Claude-compatible
marketplace, once per machine —

```
omp plugin marketplace add anthropics/claude-plugins-official
omp plugin install superpowers@claude-plugins-official
```

State lands in `~/.omp/plugins/installed_plugins.json` (imperative, like Claude's
plugin cache).

**Plan verification items:**

- whether superpowers' session-start hook fires under omp (fallback: one
  AGENTS.md line pointing at the using-superpowers skill);
- what superpowers' per-harness adaptation does under omp;
- confirm omp does not rewrite `mcp.json` at runtime (the declarative symlink
  assumes it is read-only to omp, like Claude's keybindings.json).

## Tasks

1. **Shared skills dir.** Create the shared source directory; move the nine
   portable skills into it (rewriting using-skills and writing-skills
   tool-agnostically, and sweeping all nine for claude-only skill links and
   Claude-specific machinery references); merge `readSkills` over both source
   dirs at the claude-code call site; validate cedar's home still renders
   every skill.
2. **Context + rules.** Write `config/AGENTS.md` and `config/RULES.md` in the
   omp module folder and wire the `home.file` entries; wire the shared skills
   into `home.file.".omp/agent/skills/…"`.
3. **Agent roster.** Port the ten load-bearing agents into
   `config/agents/*.md` with omp frontmatter and adapted tool names; wire a
   `readMarkdown`-shaped reader to `home.file.".omp/agent/agents/<n>.md"`.
4. **mcp.json + config.yml policy.** Add the declarative `mcp.json` and the
   yq activation merge with the provider/theme/approval-mode policy.
5. **Validate.** Eval the three jakeneau homes (activationPackage drvPath, per
   [`packaging.md`](packaging.md)'s validation strategy); confirm cedar's home
   is byte-identical for everything claude-code manages **except** the two
   deliberately rewritten skills (using-skills, writing-skills), whose diffs
   flow into cedar's rendered `~/.claude/skills/` by design and are reviewed
   intentionally.
