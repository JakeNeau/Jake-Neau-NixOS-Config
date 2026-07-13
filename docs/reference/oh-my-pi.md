# The oh-my-pi module

`modules/programs/oh-my-pi/oh-my-pi.nix`: the `flake.programs.oh-my-pi`
declaration installing the omp coding agent per-user, its flake input and
binary-cache aspect, and the declarative `~/.omp/agent/` config it carries.
Why omp, and why it routes per user:
[coding agents](../explanation/coding-agents.md).

## The declaration

- `install.linux = ["home"]`, `install.macos = ["home"]` — per-user on both
  platforms. Delivered today by `flake.users.jakeneau.programs`
  ([add a per-user program](../how-to/add-a-per-user-program.md)).
- `hasEnableOption = false` + `packages` — no home-manager
  `programs.oh-my-pi` module exists, so the generator supplies the enable
  toggle and installs the package behind it.
- The package is `inputs.llm-agents.packages.<system>.omp`, from
  **llm-agents.nix** (`github:numtide/llm-agents.nix`), declared via
  `flake-file.inputs` in the same file. The input deliberately has no
  `nixpkgs.follows`: cache.numtide.com only holds builds against the flake's
  own pin, and following our nixpkgs would rebuild omp and miss the cache.

## The numtide cache aspect

`flake.modules.generic.numtide-cache`, in the same file:

- `nix.settings.extra-substituters = ["https://cache.numtide.com"]` and the
  matching `extra-trusted-public-keys` entry — the `extra-` prefix appends to
  the defaults instead of replacing them.
- System-scoped: all four hosts import it in their quirks aspects, never
  homes. It reaches the nix daemon only at a machine's next system rebuild;
  an omp home built before that compiles omp's Rust core from source.

## The rendered `~/.omp/agent/` tree

The `config` module renders omp's native global config directory (native
discovery priority 100, so it beats the `.claude`-compat providers):

| path | content | source |
|---|---|---|
| `AGENTS.md` | global context, discovered natively (walk-up included) | `config/AGENTS.md` |
| `RULES.md` | sticky rules; omp re-injects them near the current turn | `config/RULES.md` |
| `skills/<name>/SKILL.md` | the shared skills | `modules/programs/agents-shared/skills/` |
| `agents/<name>.md` | the eighteen task agents, in omp frontmatter with omp tool names | `config/agents/` |
| `extensions/flow-map.ts` | injects the development-flow map once per process (`before_agent_start`) | `config/extensions/flow-map.ts` |
| `mcp.json` | MCP servers | generated JSON (below) |
| `config.yml` | omp's own settings file — never owned; policy merged in (below) | — |

The task agents — the full Claude Code subagent roster: bug-finder,
code-reviewer, code-writer, codebase-investigator, comment-style-enforcer,
comment-writer, doc-reader, doc-reviewer, doc-writer, git-vcs, jujutsu-vcs,
plan-verifier, spec-reader, spec-writer, test-verifier, test-writer,
todo-writer, web-researcher.

`mcp.json` declares the `nixos` server with its command pinned to the store
path of `pkgs.mcp-nixos` (`lib.getExe`). It is a read-only symlink: omp only
writes the file from explicit `/mcp` config commands, which fail loudly on
it — acceptable, since servers are declared here by design.

## The `config.yml` policy merge

omp rewrites `config.yml` at runtime (`/settings`, `omp config set`), so it
cannot be a store symlink. Instead `home.activation.ompConfigPolicy`
deep-merges a policy into the live file with `yq-go` (`eval-all
'select(fileIndex == 0) * select(fileIndex == 1)'`); the policy is
materialised as a store JSON file (JSON is valid YAML) because yq has no
`--argjson`. Policy keys win; a missing or empty file is seeded with `{}`
first (an empty input would make the merge emit nothing and truncate).

Policy keys:

- `tools.approvalMode = "always-ask"` — omp defaults to yolo; always-ask
  auto-approves read-tier tools only and prompts for write/exec.
- `modelProviderOrder = ["anthropic"]` — prefer Anthropic (subscription
  OAuth) when a canonical model id could resolve to several providers.
- `symbolPreset = "nerd"` — terminals here run a Nerd Font.

Runtime knobs (color theme, model choice) are deliberately absent so
`/settings` and `/model` changes survive rebuilds.

## State outside Nix

One piece of per-machine state is imperative by design, set up once:

- **Auth** — `/login` in omp (Anthropic subscription OAuth); tokens land in
  `agent.db` under `~/.omp/agent/`, never in Nix.

Ordering note: a machine's first omp home build should follow a system
rebuild, so the numtide cache (above) is active.
