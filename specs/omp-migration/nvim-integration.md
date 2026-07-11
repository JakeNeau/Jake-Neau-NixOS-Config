# Neovim integration: codecompanion via ACP, localAI removal

Sub-spec of [`omp-migration.md`](omp-migration.md): the nvf editor integration for
omp machines, the conditional that routes each home to the right AI plugin, and
the removal of the localAI stack with its shortcuts ported forward.

All edits land in `modules/programs/nvf/nvf.nix` unless a path says otherwise.

## Spec

1. **Three-way conditional** in the nvf homeManager aspect: a home that enables
   oh-my-pi gets **codecompanion.nvim** (talking to omp over ACP); a home that
   enables claude-code keeps **claudecode.nvim** (today's config verbatim); a
   home with neither gets no AI plugin.
2. **codecompanion.nvim** connects to omp through a custom ACP (Agent Client
   Protocol) adapter running `omp acp` — omp routes edits through ACP's
   `session/request_permission`, and omp owns auth, so nvim holds no API key.
3. **localAI is removed entirely** — the llama-server service, the local-ai
   role, the hostConstants fact, and every nvf piece that hangs off it.
   Accepted consequences, recorded: **FIM ghost-text autocomplete is gone
   everywhere, with no replacement**; **cedar loses `<leader>ak/aq/ah` entirely**
   (the ports below target codecompanion machines only, and cedar keeps
   claudecode.nvim).
4. The three `llama_explain` shortcuts are **ported to codecompanion
   prompt-library entries** on omp machines, keeping their keys and intent but
   upgraded from a 512-token local model to the full agent.

## Plan

### 1. The three-way conditional

The nvf aspect checks the *sibling program state in the same home config* — no
hostConstants needed (the localAi read-through precedent disappears with it):

- oh-my-pi enabled → `config.programs.oh-my-pi.enable` — but that option only
  exists in homes where the generated oh-my-pi unit is imported, so the lookup
  is attrByPath-style (`lib.attrByPath ["programs" "oh-my-pi" "enable"] false
  config`); claude-code likewise (`["programs" "claude-code" "enable"]`).
- Branching is **content-conditional via `lib.mkIf`**, exactly like the existing
  `localAi` pattern (a `let` binding at the top of the module, `lib.mkIf` /
  `lib.optionals` at each use site) — **never conditional imports** (nix-config
  aspect rule).
- Precedence: oh-my-pi wins if somehow both are enabled; else claude-code; else
  nothing.

The existing `claudecode.nvim` lazy-plugin block (its `cmd` list and the
`<leader>a*` keymaps) is kept verbatim, gated on the claude-code branch.

The which-key `<leader>a` group label (`nvf.nix:697`), today registered
unconditionally as "AI/Claude Code", joins the conditional: the claude-code
branch keeps "AI/Claude Code", the oh-my-pi branch registers "AI/CodeCompanion",
and the no-agent branch registers no group.

Forward-compat tension, accepted for now: the planned standalone-nvf migration
(`nvf.lib.neovimConfiguration`, per the nvf skill) cannot read
`config.programs.*` from a home, so this three-way conditional deepens the
home-config coupling that migration will need to unwind (per-variant builds or
specialArgs).

### 2. codecompanion.nvim + the omp ACP adapter

- Package: nixpkgs `vimPlugins.codecompanion-nvim`, as a `lazy.plugins` entry
  lazy-loaded on `cmd`/`keys` like claudecode.nvim.
- A custom ACP adapter whose command runs `omp acp`. **Plan verification item:**
  confirm the custom ACP adapter config shape against current codecompanion
  docs before writing it.
- Keymaps preserve the `<leader>a` intent family (mode `n` unless noted):

| key | intent | action |
|---|---|---|
| `<leader>at` | toggle chat | `CodeCompanionChat Toggle` |
| `<leader>af` | focus chat | focus the chat window |
| `<leader>ar` / `<leader>ac` | resume last session | **plan verification item:** chat-history vs ACP `session/load` command shape |
| `<leader>am` | model picker | **plan item:** current mechanism for ACP adapters |
| `<leader>ab` | add current buffer | add buffer to chat context |
| `<leader>as` (v) | send selection | `CodeCompanionChat Add` |
| `<leader>as` (n, ft: NvimTree/neo-tree/oil/minifiles/netrw/snacks_picker_list) | add file under cursor | mirrors the claudecode TreeAdd binding |
| `<leader>ai` (n+v) | inline assistant | `:CodeCompanion` |
| `<leader>aa` | actions palette | `:CodeCompanionActions` |

- Diff accept/reject stays on codecompanion's buffer-local in-diff defaults —
  **not** global binds (so `<leader>aa`'s claudecode meaning is free to become
  the actions palette).

### 3. localAI removal

Delete, in one sweep:

- `modules/services/llama-server/` (whole folder);
- `modules/host-config/roles/local-ai/` (whole folder);
- the `localAi` option from
  `modules/host-config/host-constants/host-constants.nix`;
- the `local-ai` import from `modules/hosts/cedar/configuration.nix` (in the
  darwin quirks aspect's imports) and from
  `modules/hosts/redwood/configuration.nix` (in the nixos quirks aspect's
  imports);
- in `nvf.nix`: the `localAi` let binding, `globals.llama_config`,
  `highlight.llama_hl_fim_hint`, the `"llama.vim"` lazy-plugin entry, the
  `lib.optionals localAi` keymap block (`ak`/`aq`/`ah`),
  `luaConfigRC.llamaExplain`, and `luaConfigRC.llamaPicker`;
- the docs' localAI references — four in total: the
  `local-ai`/`hostConstants.localAi` passage in
  `docs/explanation/host-facts.md`, the `local-ai` entry in the feature
  imports list of `docs/how-to/add-a-host.md`, and **two** entries in
  `docs/reference/feature-index.md` — the `local-ai/` entry and the separate
  `llama-server/` services entry (`docs/reference/feature-index.md:165`);
- the repo's own skill files, which go stale with the removal:
  `.agents/skills/nix-config/SKILL.md:144` drops the `local-ai` role from its
  role list, and `.agents/skills/nix-config/aspects.md:252` swaps its `localAi`
  Constants example for another hostConstants fact such as `isLaptop`.

The `hostConstants` read-through machinery itself stays — other home-side
consumers (fish's `minecraftServer`, fastfetch's `hostName`/`isLaptop`) still
use it.

### 4. Porting ak/aq/ah to codecompanion (omp machines only)

Prompt-library entries plus keymaps in the oh-my-pi branch, keeping keys and
intent:

- **`<leader>ak` (n/x) — explain, why-focused.** Prompt asks for "purpose and
  reasoning, not a line-by-line description" (the current `llama_explain`
  wording); context is the visual selection or the symbol under the cursor, as
  today.
- **`<leader>aq` (n/x) — ask.** `vim.ui.input`-style free-form question plus the
  same selection-or-symbol context.
- **`<leader>ah` — "How do I…?"**, fixed to be actually useful. The prompt
  includes:
  1. the question;
  2. the **live keymap/command corpus** — port the existing `keymap_corpus` /
     `command_corpus` lua from `luaConfigRC.llamaExplain` (runtime truth beats
     reading config);
  3. a pointer telling the agent that the nvim config source lives at
     `<repo>/modules/programs/nvf/nvf.nix`, with the repo root **baked in at
     build time per platform** — `/etc/nixos` on Linux, `/etc/nix-darwin` on
     Darwin, selected via `pkgs.stdenv.isDarwin` — and that it may read/grep it.
     The ACP session is a full omp agent with read/grep tools, so it can quote
     the actual config, which the 512-token local model never could.

### Validation

`nix flake check`; the three jakeneau homes by activationPackage drvPath eval
(aspen exercises the oh-my-pi branch on darwin, redwood/spruce on Linux — never
full-built, per [`packaging.md`](packaging.md)'s validation strategy); cedar's
home (the claude-code branch) and both darwin systems by `nix build --no-link`;
redwood/spruce toplevel drvPath eval (llama-server removal touches the system
layer).

## Tasks

1. **Conditional + verbatim claudecode gate.** Introduce the attrByPath-based
   oh-my-pi/claude-code/none branching; gate the existing claudecode.nvim block
   on the claude-code branch; validate cedar's home is unchanged in content.
2. **codecompanion + ACP adapter.** Add the codecompanion-nvim lazy plugin, the
   `omp acp` adapter (after resolving the adapter-shape verification item), and
   the keymap family; validate the three jakeneau homes.
3. **localAI removal.** Delete the service, role, hostConstants fact, host
   imports, all nvf localAi pieces, the four docs references, and the two
   nix-config skill-file references; validate both system layers and all homes.
4. **Shortcut ports.** Add the ak/aq/ah prompt-library entries and keymaps
   (porting the corpus lua and baking in the per-platform repo root); validate
   the jakeneau homes.
