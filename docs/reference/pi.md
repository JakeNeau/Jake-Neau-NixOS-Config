# The pi module

`modules/programs/pi/pi.nix`: the `flake.programs.pi` declaration installing
and configuring the `pi` coding agent per user. It supplies two web
capabilities: structured research through **pi-web-access**, and real-browser
fallback through **pi-agent-browser-native** plus the `agent-browser` CLI. Why
pi, and why it routes per user: [coding agents](../explanation/coding-agents.md).

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
global link manifest and prompts, librarian and extension-authoring skill links,
and the two policy files above.

## The numtide cache aspect

`flake.modules.generic.numtide-cache`, in the same file, appends
`https://cache.numtide.com` and its trusted key to the daemon settings. Hosts
import it at system scope; homes never do. It reaches the daemon on the next
system rebuild.
