# The pi module

`modules/programs/pi/pi.nix`: the `flake.programs.pi` declaration installing
and configuring the `pi` coding agent per user. It supplies two web
capabilities: structured research through **pi-web-access**, and real-browser
fallback through **pi-agent-browser-native** plus the `agent-browser` CLI. It
also installs the `pi-acp` adapter used by Neovim. Why pi, and why it routes per
user: [coding agents](../explanation/coding-agents.md).

## The declaration

- `install.linux = ["home"]`, `install.macos = ["home"]` — per-user on both
  platforms. Delivered by `flake.users.jakeneau.programs`.
- `hasEnableOption = false` + `packages` — the generator supplies the enable
  toggle and installs both pi and `agent-browser` behind it.
- Pi comes from `inputs.llm-agents.packages.<system>.pi`, via
  **llm-agents.nix** (`github:numtide/llm-agents.nix`). The input deliberately
  does not follow this flake's nixpkgs, preserving numtide's binary-cache hit.
- `agent-browser` is the upstream release binary, selected and hash-pinned per
  supported Linux/macOS architecture. Linux binaries are patched for NixOS.

## Web extensions

The module pins both extension sources as non-flake inputs:

- `pi-web-access` `v0.13.0` — `web_search`, content extraction, PDFs, GitHub,
  video handling, and its librarian skill.
- `pi-agent-browser-native` `v0.2.71` — the native `agent_browser` tool for
  JavaScript rendering and interactive browser workflows. It targets the
  installed `agent-browser` `0.32.2` release.

pi-web-access's runtime dependencies are built with `buildNpmPackage`; the
committed `pi-web-access-package-lock.json` and `npmDepsHash` make that build
reproducible. Small generated `index.ts` files under
`~/.pi/agent/extensions/` import each extension from its immutable store path.
The bundled librarian skill is linked under `~/.pi/agent/skills/`.

## Neovim ACP adapter

The unversioned non-flake `pi-acp` input is commit-pinned by `flake.lock` and
built with `buildNpmPackage`. Upstream Pi exposes `pi --mode rpc`, while
codecompanion.nvim speaks the standard Agent Client Protocol; `pi-acp` bridges
the two JSON protocols over stdio.

The nvf module enables codecompanion.nvim only when the sibling `programs.pi`
unit is enabled in the same home. Its custom `pi` ACP adapter launches
`pi-acp`, enables embedded context, and makes Pi the default chat adapter.
CodeCompanion receives streamed messages, tool activity, file diffs, model and
thinking options, slash commands, and persistent Pi sessions. Pi continues to
execute filesystem and shell tools locally; ACP filesystem and terminal
delegation are not enabled.

## Typed-link navigation

The `typed-links` extension resolves the shared `[[type:name]]` convention
through the `follow_link` tool. Pi supports four link types:

- `skill` — loads a skill body and optional arguments.
- `command` — expands a Pi prompt template and its arguments.
- `spec` — loads a project specification.
- `doc` — loads a project documentation page.

Claude-specific types are treated as foreign and never guessed. Typed-link
examples inside Markdown code spans and fences are ignored. MCP and extension
adapters are not implemented.

Home Manager builds the global registry at
`~/.pi/agent/link-registry.json` from:

- `modules/programs/agents-shared/skills/`
- `modules/programs/pi/config/skills/`
- `modules/programs/pi/config/prompts/`

The manifest contains metadata and immutable source paths, not resource bodies.
The same dependency-free compiler scans these project paths after Pi trusts the
project:

- `.agents/skills/**/SKILL.md`
- `.pi/skills/**/SKILL.md`
- `.pi/prompts/*.md`
- `specs/**/*.md`
- `docs/**/*.md`

Global and project registries remain separate. Links from a registered resource
resolve inside its own layer; an unqualified user link matching both layers is
reported as ambiguous. Ordinary `read` results containing supported links gain
a compact footer with canonical targets, but no target loads automatically.

`/links` reports registry counts, `/links unresolved` lists diagnostics,
`/links <type>:<name>` inspects one resource, and `/links reload` reloads Pi's
resources and rescans the project. Tool output follows Pi's standard truncation
limits and points to the full source path when truncated.

The global `writing-pi-extensions` skill is installed under
`~/.pi/agent/skills/`. It requires extension designs to decide whether they
introduce a durable resource kind that needs a typed-link adapter. The registry's
design rationale is documented in
[Pi typed-link navigation](../explanation/pi-typed-links.md).

## Writing system

The managed global context file `~/.pi/agent/AGENTS.md` contains one writing
route. Pi follows `global:skill:writing` before it writes or revises prose. The
route covers user output, documentation, comments, plans, reviews, and interface
text.

The router loads focused policy bodies through typed links:

- `global:skill:writing-substance` controls purpose, claims, support, relations,
  consequences, and artifact order.
- `global:skill:controlled-writing` controls terms, vocabulary, sentences,
  voice, lists, paragraphs, and protected text.
- `global:skill:comments` controls whether a code comment exists and which
  comment policy applies.
- `global:skill:documentation` controls documentation architecture and
  placement when those decisions are part of the task.

The router contains links and classification rules only. Policy bodies remain
outside startup context. Pi loads each selected body at most once per task.

The `pi-writing-lint` command checks Markdown, plain text, or standard input. It
returns `0` without diagnostics, `1` with diagnostics, and `2` for input errors.
Use `--json` for structured output. Deterministic and heuristic diagnostics both
produce exit code `1`. Heuristic diagnostics include a `candidate` marker.

Pi runs the linter after it changes a supported standalone prose file. Embedded
comments and interface strings use model review because a whole source file
mixes code with prose. User output uses an internal final check because Pi has no
safe revise-before-send event.

The global `/writing-review [scope]` prompt reviews substance before form. Its
default scope is prose changed in `git diff HEAD`. A supplied path, directory,
or range replaces the default.

The design rationale is in
[Pi's writing system](../explanation/pi-writing-system.md).

## Comment policy

The writing router follows `global:skill:comments` before it applies general
prose rules to a code comment. The shared comment skill classifies the comment,
then links to one focused category policy. Categories cover redundant narration,
rationale, invariants, workarounds, API contracts, structural markers,
functional directives, provenance, task markers, and disabled code. Category
bodies load only when encountered. Ordinary prose targets one line and has a
two-line ceiling.

The global `/comment-review [scope]` prompt conforms comments automatically. Its
default scope is comments added, deleted, or modified in `git diff HEAD`; a
supplied path or range replaces that default, and naming a file reviews every
comment in it. The workflow changes comments only, works deletion-first, and
preserves functional directives and legal or generated provenance verbatim.

## Managed policy

Home Manager owns two focused policy files:

- `~/.pi/web-search.json` selects Exa, disables the interactive curator with
  `workflow = "none"`, and forbids browser-cookie extraction. This makes
  unattended runs return raw evidence to the main agent.
- `~/.pi/config/pi-agent-browser-native/config.json` disables that extension's
  companion search tool. pi-web-access owns search; `agent_browser` remains the
  JavaScript-capable fallback.

API keys are not stored in Nix. pi-web-access reads `EXA_API_KEY`,
`BRAVE_API_KEY`, and its other supported provider variables from the process
environment. Add credentials through sops-nix when needed.

Pi's mutable `~/.pi/agent/settings.json`, authentication, model catalog, and
session state remain outside Nix. The module owns the extension entry points,
global context, link manifest, prompts, writing linter, and focused skill links.
It also owns the two web policy files above.

## The numtide cache aspect

`flake.modules.generic.numtide-cache`, in the same file, appends
`https://cache.numtide.com` and its trusted key to the daemon settings. Hosts
import it at system scope; homes never do. It reaches the daemon on the next
system rebuild.
