# Pi handoff and LSP diagnostics

Install two Pi extensions declaratively: Pi's bundled handoff example and the
third-party `@narumitw/pi-lsp` diagnostics extension. Pi's language servers come
from the Neovim (nvf) configuration of the same home.

## Spec

### Purpose

- **Handoff:** The `jakeneau` homes disable automatic compaction. The footer
  tells the user to start a new session at 20% and 50% context use. `/handoff`
  makes that switch cheap. It writes a focused prompt from the current
  conversation and opens a new session with that prompt as a draft.
- **LSP diagnostics:** Pi has no diagnostics for Nix or for most other
  languages in these homes. `rust_code` covers Rust only. `@narumitw/pi-lsp`
  gives the agent the `lsp_diagnostics` and `lsp_fix` tools for any configured
  language server.
- **One source of language servers:** Neovim and Pi use the same server, binary,
  and version for each language. When nvf enables a language, Pi also
  receives that language.

### Fixed facts

On 2026-10-18, Pi checked these facts against Pi 1.3.0, nvf's evaluated home
configuration, and the `@narumitw/pi-lsp` 0.49.10 tarball.

- Pi ships `libexec/pi/examples/extensions/handoff.ts` in its package. The
  extension registers the `/handoff <goal>` command. The command works only in
  TUI mode. It sends the current branch to the selected model and shows the
  generated prompt in an editor. Then it opens a new session whose parent is the
  current session, and it puts the edited prompt in the input editor without
  submitting it. Pi has no built-in `handoff` command.
- `@narumitw/pi-lsp` has no runtime dependencies. Its peer dependencies,
  `@earendil-works/pi-coding-agent` and `typebox`, come from Pi. The published
  tarball contains the built entry point `dist/index.ts`.
- `@narumitw/pi-lsp` registers the tools `lsp_diagnostics` and `lsp_fix` and the
  command `/lsp`. It starts a server for each tool call and stops the server
  after the call. It never downloads servers. Diagnostics run only when the
  agent calls the tool.
- `@narumitw/pi-lsp` reads the first configuration it finds in this order:
  trusted project `.pi/pi-lsp.json`, `~/.pi/agent/pi-lsp.json`, and its built-in
  catalog. Any configuration replaces the entire built-in catalog. A server
  entry is `{ command = [argv]; extensions = [".ext"]; }`. The extension never
  writes its configuration file.
- `@narumitw/pi-lsp` checks configured commands strictly. A missing configured
  command makes the tool call fail. The extension skips a missing command
  from its built-in catalog.
- `lsp_fix` with `write = true` writes outside Pi's file-mutation queue.
- `programs.nvf.settings.vim.lsp.servers` holds every server that nvf
  configures. Each entry has a `cmd` and its Neovim `filetypes`. Most `cmd`
  values are argv lists of Nix store paths. `jdt-language-server` builds its
  `cmd` with inline Lua. The `"*"` entry holds defaults for all servers and has
  no `cmd`.
- Every home that requests Pi (`jakeneau@redwood`, `jakeneau@spruce`, and
  `jakeneau@aspen`) enables nvf through the desktop role.

### Decisions

1. **Handoff source:** The entry point re-exports `handoff.ts` from the
   installed Pi package. The repository adds no input, copy, or patch. The
   extension updates with Pi.
2. **pi-lsp source:** A non-flake npm tarball input pins
   `@narumitw/pi-lsp` 0.49.10, like `pi-usage-limits`. A new release requires a
   URL change. Nix copies the tarball unchanged, and the entry point re-exports
   `dist/index.ts`.
3. **Server configuration:** Home Manager writes
   `~/.pi/agent/pi-lsp.json` as a read-only Nix store link. The extension never
   writes the file, so no activation merge is needed. The file uses the
   `servers` form and contains only servers derived from nvf.
4. **Derivation from nvf:** For each nvf server, the module copies the `cmd`
   argv as `command`. It maps the server's Neovim filetypes to file extensions
   through one explicit table in `pi.nix`. The table covers the filetypes of
   every derived server. Examples are `nix → .nix`, `python → .py .pyi`, and
   `yaml → .yaml .yml`. A filetype without a matching extension contributes
   nothing, for example `gomod`.
5. **Excluded servers:**
   - `rust-analyzer`: `rust_code` owns Rust. A second `rust-analyzer` would
     analyze the workspace again on every pi-lsp call.
   - `"*"`: holds defaults and is not a server.
   - Any server whose `cmd` is not a list of strings. Today this is
     `jdt-language-server`.
   - `helm-ls`: Helm templates share `.yaml` with `yaml-language-server`. Pi
     cannot identify them by extension.
6. **Sync guard:** A Home Manager assertion fails the home build in one case. A
   derived server, which is any server except the excluded ones, yields no file
   extension. The error names the server and its filetypes. A new nvf language
   therefore requires a table entry or an exclusion in the same change.
7. **No nvf:** When the home disables `programs.nvf` or nvf's LSP, Home Manager
   writes no `pi-lsp.json`. pi-lsp then uses its built-in catalog from `PATH`.
   The extension still loads.
8. **Server settings:** The module copies no nvf `settings` or `init_options`.
   Some of them contain inline Lua. Diagnostics work with server defaults.

### Behavior

After the change and a home activation, a new interactive Pi session behaves as
follows:

1. `/handoff <goal>` produces an editable prompt and opens a child session with
   that prompt in the editor. Pi does not submit the prompt.
2. `/handoff` without a goal, outside TUI mode, or without a model shows an
   error and changes nothing.
3. The agent can call `lsp_diagnostics` on `.nix` files and receive `nil`
   diagnostics from the store path that Neovim uses.
4. Every derived language behaves the same way with its nvf server.
5. `lsp_diagnostics` on a `.rs` file reports that no server matches. `rust_code`
   remains the Rust path.
6. `/lsp` lists the derived servers and shows each command as available.
7. A trusted project's `.pi/pi-lsp.json` replaces the derived servers for that
   project.

### Constraints

- Install everything declaratively. Do not use `pi install` or edit files under
  `~/.pi/agent/` by hand.
- Do not hand-edit `flake.nix`. Declare the input in `flake-file.inputs`, run
  `nix run .#write-flake`, and lock only the new input.
- Do not add physical copies of `@earendil-works/*` or `typebox`.
- Do not run `nix flake update`, `hr`, `nr`, or `nrr`.
- Do not change the nvf configuration.

### Non-goals

- Automatic diagnostics after edits. The agent calls `lsp_diagnostics`.
- Symbol navigation, references, or rename through pi-lsp.
- Moving Rust diagnostics or navigation out of `rust_code`.
- Java and Helm diagnostics.
- Persistent language-server sessions.
- Changes to the handoff prompt or behavior.

### Acceptance criteria

- `nix flake check` passes.
- The `jakeneau` home builds on `redwood` and evaluates on `spruce` and `aspen`.
- The `pi-third-party-extensions` check loads both extensions and finds the
  `handoff` and `lsp` commands. It confirms that the pi-lsp package contains no
  `node_modules`.
- On `redwood`, the generated `pi-lsp.json` contains `nil` with `.nix`. It
  contains no `rust-analyzer`, `jdt-language-server`, `helm-ls`, or `"*"`
  entry.
- An nvf server with no mapped extension that is not excluded fails the home
  build with the assertion message.
- `docs/reference/pi.md` describes both extensions, the nvf derivation, the
  exclusions, and the tarball update rule. The `pi/` entry in
  `docs/reference/feature-index.md` mentions handoff and LSP diagnostics.
- After the user runs `hr`, a manual session confirms behaviors 1, 3, 5,
  and 6.

## Plan

### Verified facts

- `modules/programs/pi/pi.nix` starts with `{ inputs, ... }:`. Its top `let`
  block defines the package builders and checks. `perSystem.checks` registers
  each check.
- `mkPiThirdPartyExtensionsCheck` writes one re-export per extension under
  `extensions/<name>/index.ts`. It loads all of them in one RPC `get_commands`
  call and greps `rpc.jsonl` for command names. It then runs `test ! -e` on
  the library copies.
- `fixedHomeFiles` holds the extension entry points. `homeAssistantMcpFiles`
  is the precedent for a conditional file:
  `lib.optionalAttrs <condition> { ... }`, merged into `home.file`.
- `pi-anthropic-auth` and `pi-usage` re-export straight from their non-flake
  inputs with no derivation. `pi-lsp` needs no patch or dependency, so it
  follows that precedent.
- The Pi 1.3.0 store path contains
  `libexec/pi/examples/extensions/handoff.ts`. It imports
  `@earendil-works/pi-agent-core`, `@earendil-works/pi-ai`, and
  `@earendil-works/pi-coding-agent`, which Pi's loader supplies. The file
  registers `handoff`.
- nvf's `lspOptions` (`lib/languages.nix`) types each server as a freeform
  submodule. It has `enable` (bool, default `true`), `filetypes`
  (`nullOr (listOf str)`), and `cmd`
  (`nullOr (either luaInline (listOf str))`). nvf always defines `"*"` with
  `cmd = null`. nvf writes `vim.lsp.servers` even when `vim.lsp.enable` is
  false.
- The current nvf build defines these servers and filetypes:
  - `bash-language-server`: `bash sh ash dash`
  - `clangd`: `c cpp objc objcpp cuda proto`
  - `dart`: `dart`
  - `gopls`: `go gomod gosum gowork gotmpl`
  - `helm-ls`: `helm yaml.helm-values`
  - `jdt-language-server`: `java`, with a Lua `cmd`
  - `lua-language-server`: `lua`
  - `marksman`: `markdown`
  - `nil`: `nix`
  - `pyright`: `python`
  - `rust-analyzer`: `rust`
  - `superhtml`: `html xhtml`
  - `svelte-language-server`: `svelte`
  - `taplo`: `toml`
  - `typescript-language-server`: `typescript javascript`
  - `vscode-css-language-server`: `css less`
  - `vscode-json-language-server`: `json jsonc`
  - `yaml-language-server`: `yaml yaml.gitlab`
- The nvf module reads `programs.pi.enable` through `lib.attrByPath`. Pi reads
  only nvf's server data, so the dependency between the two modules does not
  form a cycle.

### Design decisions

1. **Handoff entry point:** `.pi/agent/extensions/handoff/index.ts`
   re-exports
   `"${mkPiPackage pkgs}/libexec/pi/examples/extensions/handoff.ts"`.
   `mkPiPackage pkgs` is the same derivation that `packages` installs. The
   extension therefore matches the installed Pi.
2. **pi-lsp entry point:** `.pi/agent/extensions/pi-lsp/index.ts` re-exports
   `"${inputs.pi-lsp}/dist/index.ts"`. The flake fetcher unpacks the tarball
   and strips the top `package/` directory. No builder exists.
3. **Derivation as pure functions:** The derivation lives in the top `let`
   block, so the home module and a pure check share it. Add `lib` to the
   module arguments: `{ inputs, lib, ... }:`.
4. **Enabled servers only:** The filter also drops servers with
   `enable = false`, because Neovim does not start them.
5. **Extension table:** The table contains only filetypes that have an
   extension. A lookup uses `or [ ]`. Filetypes that the table omits
   contribute nothing: `ash dash proto gomod gosum gowork gotmpl yaml.gitlab`.
   The guard is per server, so a server with at least one mapped filetype
   passes.
6. **Condition:** `nvfLsp` is true when both `programs.nvf.enable` and
   `programs.nvf.settings.vim.lsp.enable` are true. Each value is read with
   `lib.attrByPath ... false config`, because homes without the desktop role
   do not import the nvf module. When `nvfLsp` is false, the module writes no
   `pi-lsp.json` and adds no assertions.
7. **JSON shape:**
   `{ servers = { "<nvf name>" = { command = [ argv ]; extensions = [ ".ext" ]; }; }; }`.
   The nvf names become the names that `/lsp` shows. The `cmd` strings keep
   their store-path context, so the home closure references the same server
   binaries as Neovim.

### `modules/programs/pi/pi.nix`

Top `let` block, after `npmVersion`:

- `piLspExcluded = [ "*" "rust-analyzer" "helm-ls" ];`, with a one-line
  comment for each exclusion reason: defaults entry, `rust_code` owns Rust, and
  Helm shares `.yaml`.
- `piLspExtensions`, the explicit filetype table:
  - `bash = [ ".bash" ]`, `sh = [ ".sh" ]`
  - `c = [ ".c" ".h" ]`,
    `cpp = [ ".cc" ".cpp" ".cxx" ".hh" ".hpp" ".hxx" ]`
  - `objc = [ ".m" ]`, `objcpp = [ ".mm" ]`, `cuda = [ ".cu" ".cuh" ]`
  - `css = [ ".css" ]`, `less = [ ".less" ]`
  - `dart = [ ".dart" ]`, `go = [ ".go" ]`, `lua = [ ".lua" ]`
  - `html = [ ".html" ".htm" ]`, `xhtml = [ ".xhtml" ]`
  - `json = [ ".json" ]`, `jsonc = [ ".jsonc" ]`
  - `markdown = [ ".md" ".markdown" ]`, `nix = [ ".nix" ]`
  - `python = [ ".py" ".pyi" ]`, `svelte = [ ".svelte" ]`,
    `toml = [ ".toml" ]`
  - `typescript = [ ".ts" ".mts" ".cts" ]`,
    `javascript = [ ".js" ".mjs" ".cjs" ]`
  - `yaml = [ ".yaml" ".yml" ]`
- `piLspServers = servers: ...` returns an attrset keyed by server name:
  - It filters with
    `name: server: server.enable && builtins.isList server.cmd && !lib.elem name piLspExcluded`.
  - It maps each server to
    `{ command = server.cmd; extensions = lib.concatMap (filetype: piLspExtensions.${filetype} or [ ]) (if server.filetypes == null then [ ] else server.filetypes); }`.
- `piLspAssertions = servers: lib.mapAttrsToList (...) (piLspServers servers)`.
  Each derived server yields one assertion:
  - `assertion = server.extensions != [ ];`
  - The message is
    `pi-lsp: nvf server <name> has no file extension for filetypes <space-separated filetypes>. Add the filetypes to piLspExtensions or the server to piLspExcluded in modules/programs/pi/pi.nix.`
    The message reads the filetypes from `servers.${name}.filetypes`.
- `mkPiLspServersCheck = pkgs: ...` evaluates the functions on a fixture. It
  returns `pkgs.runCommand "pi-lsp-servers" { } "touch $out"` behind `assert`
  expressions. The fixture contains these servers:
  - `"*"` with `cmd = null`.
  - `rust-analyzer` and `helm-ls` with list `cmd` values and mapped filetypes.
  - `jdt-language-server` with `cmd = lib.generators.mkLuaInline "{}"`.
  - A disabled server with a list `cmd`.
  - `nil` with `[ "nix" ]`.
  - `gopls` with `[ "go" "gomod" ]`.
  - `fixture-ls` with `[ "fixture" ]`.
- Each fixture entry sets `enable`, `cmd`, and `filetypes`.
- The check asserts these results:
  - `piLspServers fixture` equals exactly
    `{ nil = { command; extensions = [ ".nix" ]; }; gopls = { ...; extensions = [ ".go" ]; }; fixture-ls = { ...; extensions = [ ]; }; }`.
  - `lib.filter (a: !a.assertion) (piLspAssertions fixture)` has one element.
    Its message contains `fixture-ls` and `fixture`.
- Register `pi-lsp-servers = mkPiLspServersCheck pkgs;` in
  `perSystem.checks`.

`mkPiThirdPartyExtensionsCheck`:

- Add `handoff` and `lsp` to the `mkdir -p extensions/{...}` list.
- Write `extensions/handoff/index.ts` as a re-export of
  `${mkPiPackage pkgs}/libexec/pi/examples/extensions/handoff.ts`.
- Write `extensions/lsp/index.ts` as a re-export of
  `${inputs.pi-lsp}/dist/index.ts`.
- Append both `--extension` arguments to `extension_args`.
- Add `grep -q '"name":"handoff"' rpc.jsonl` and
  `grep -q '"name":"lsp"' rpc.jsonl`. A name collision would produce a `:1`
  suffix and fail the grep.
- Add `test ! -e ${inputs.pi-lsp}/node_modules`.

`flake-file.inputs`: add this entry after `pi-claude-bridge`:

```nix
pi-lsp = {
  url = "https://registry.npmjs.org/@narumitw/pi-lsp/-/pi-lsp-0.49.10.tgz";
  flake = false;
};
```

`flake.programs.pi.config` `let` block:

- `nvfLsp`: the condition from design decision 6.
- `nvfServers = lib.attrByPath [ "programs" "nvf" "settings" "vim" "lsp" "servers" ] { } config;`
- `piLspFiles = lib.optionalAttrs nvfLsp { ".pi/agent/pi-lsp.json".text = builtins.toJSON { servers = piLspServers nvfServers; }; };`
- `fixedHomeFiles` gains these entries:
  - `".pi/agent/extensions/handoff/index.ts".text`, the handoff re-export.
  - `".pi/agent/extensions/pi-lsp/index.ts".text`, the pi-lsp re-export.

Module body:

- `home.file = fixedHomeFiles // promptHomeFiles // subagentPromptHomeFiles // homeAssistantMcpFiles // piLspFiles;`
- `assertions = lib.optionals nvfLsp (piLspAssertions nvfServers);`

Then regenerate `flake.nix`, and lock only `pi-lsp` with `nix flake lock`.

### Errors and edge cases

- An unmapped derived server fails the home evaluation with the assertion
  message. The message names the server and its filetypes.
- A home without nvf or nvf's LSP gets no `pi-lsp.json` and no assertions.
  pi-lsp then uses its built-in catalog from `PATH`.
- `rust-analyzer`, `helm-ls`, `"*"`, `jdt-language-server`, and disabled
  servers never reach the file. An `lsp_diagnostics` call on `.rs`, `.java`,
  or a Helm template therefore reports that no server matches.
- `marksman` gets `.md`. As the `claude-code` LSP comment records, marksman
  reports each `[[type:name]]` link as a broken reference. pi-lsp has no
  per-server diagnostics switch, and the spec forbids nvf changes. The
  reference page must record this limitation.

### Documentation

`docs/reference/pi.md`:

- Add `## Session handoff` before `## Neovim ACP adapter`. It must cover these
  points:
  - Spec behaviors 1 and 2.
  - The entry point re-exports Pi's bundled example, so the extension updates
    with Pi.
  - A link to the [context warning levels](#context-warning-levels) as the
    trigger to use the extension.
- Add `## LSP diagnostics` after that section. It must cover these points:
  - The `lsp_diagnostics` and `lsp_fix` tools and the `/lsp` command.
  - Each tool call starts a server and stops it afterward.
  - `lsp_fix` with `write = true` writes outside Pi's file-mutation queue.
  - Home Manager derives `~/.pi/agent/pi-lsp.json` from nvf's servers and
    uses the same store-path commands as Neovim.
  - The extension table and the four exclusions with their reasons. Link to
    [Rust code intelligence](../explanation/pi-rust-code-intelligence.md) for
    Rust.
  - The assertion, and the required action for a new nvf language: add a
    table entry or an exclusion.
  - The no-nvf fallback to the built-in catalog.
  - A trusted project `.pi/pi-lsp.json` replaces the whole derived set.
  - The marksman wikilink limitation.
- `## Extension updates`: generalize the `pi-usage-limits` paragraph to the
  npm tarball inputs. List `pi-usage-limits` 0.1.4, `pi-tidy-tools` 0.5.4, and
  `pi-lsp` 0.49.10. State that each new release requires a URL change. State
  that handoff follows the Pi package.
- `## Managed policy`: add a bullet for `~/.pi/agent/pi-lsp.json`. It is a
  read-only store link, written only when nvf's LSP is enabled. Link to the
  LSP diagnostics section.

`docs/reference/feature-index.md`: in the `pi/` entry, add session handoff and
LSP diagnostics from nvf's language servers to the feature list.

## Tasks

1. Add the `pi-lsp` input. Regenerate `flake.nix`, and lock only the new
   input.
2. In `pi.nix`, add `lib` to the module arguments. Add `piLspExcluded`,
   `piLspExtensions`, `piLspServers`, and `piLspAssertions` to the top `let`
   block.
3. Add `mkPiLspServersCheck` and register `pi-lsp-servers` in
   `perSystem.checks`.
4. Add the handoff and pi-lsp entry points to `fixedHomeFiles`. Add `nvfLsp`,
   `nvfServers`, `piLspFiles`, the `home.file` merge, and `assertions`.
5. Extend `mkPiThirdPartyExtensionsCheck` with both extensions, both command
   greps, and the `node_modules` test.
6. Update `docs/reference/pi.md` and `docs/reference/feature-index.md`, and
   run `pi-writing-lint` on both files.
7. Run `nix flake check`. Build the `jakeneau@redwood` home, and evaluate the
   `jakeneau@spruce` and `jakeneau@aspen` homes. Inspect the generated
   `pi-lsp.json` on `redwood`. It must contain `nil` with `.nix` and no
   excluded entry.
8. After the user runs `hr`, confirm spec behaviors 1, 3, 5, and 6 in a manual
   session.
