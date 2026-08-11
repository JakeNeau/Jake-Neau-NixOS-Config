# The pi module

`modules/programs/pi/pi.nix`: the `flake.programs.pi` declaration installing
and configuring the `pi` coding agent per user. It supplies two web
capabilities: structured research through **pi-web-access**, and real-browser
fallback through **pi-agent-browser-native** plus the `agent-browser` CLI. It
also installs the `pi-acp` adapter used by Neovim. Why pi, and why it routes per
user: [coding agents](../explanation/coding-agents.md).

## The declaration

- `install.linux = ["home"]`, `install.macos = ["home"]`: per-user on both
  platforms. Delivered by `flake.users.jakeneau.programs`.
- `hasEnableOption = false` + `packages`: the generator supplies the enable
  toggle and installs both pi and `agent-browser` behind it.
- Pi comes from `inputs.llm-agents.packages.<system>.pi`, via
  **llm-agents.nix** (`github:numtide/llm-agents.nix`). The input deliberately
  does not follow this flake's nixpkgs, preserving numtide's binary-cache hit.
- `agent-browser` uses the upstream release binary with a hash for each
  supported Linux/macOS architecture. The module patches Linux binaries for
  NixOS.

## Selectable questions

The `ask-user` extension registers the `ask_user` tool. The agent calls this
tool when progress requires one user decision from a short list. Pi pauses the
tool call and shows a selection dialog instead of requiring a typed reply.

Each call contains one question and between 2 and 12 distinct preset options.
The question may contain up to 500 characters. Each option contains a label of
up to 120 characters and an optional Markdown preview of up to 4,000
characters. The tool returns the selected label with its one-based index. The
tool runs sequentially, so parallel tool calls cannot open concurrent dialogs.

The agent must omit previews by default. It may add a preview when code,
commands, configuration, or another concrete example materially helps the user
compare options. It must not use a preview to repeat the label, add generic
explanation, or restate the question.

The TUI shows the preview for the highlighted option in a bordered panel. Arrow
keys change the highlighted option and preview. The panel renders Markdown and
shows at most 16 content lines. Pi marks truncated previews. The extension does
not support physical mouse-pointer hover because Pi's extension TUI API does not
expose mouse events.

The dialog always includes actions for a free-form answer and a clarifying
question. Selecting either action turns that row into a one-line input. The
question and every other option remain visible while the user types. Escape or
an empty submission restores the action label. A nonempty free-form answer
completes the tool call.

A clarifying question leaves the original decision pending. The agent answers
the clarification first. The extension then reopens the original dialog unless
the agent already called `ask_user` again. An answer or cancellation clears the
pending question.

The custom inline dialog and previews work in TUI mode. RPC mode uses Pi's
separate selection and input dialogs, accepts the same option objects, and does
not render previews. In print and JSON modes, the tool directs the agent to ask
through normal text. The extension does not support multiple selections or
multiple questions in one call.

## Workflow manager

The `workflows` extension adds exclusive, artifact-driven workflow modes.
`Shift+Tab` cycles through `normal` and discovered workflows. Home Manager moves
Pi's thinking-level cycle to `Ctrl+Shift+L`.

Each agent stage runs in a fresh RPC child process with the user's selected
model and thinking level. The parent session stores validated stage artifacts as
non-context custom entries. Global workflows live with the extension. Trusted
projects may add declarative definitions under `.pi/workflows/`.

The bundled `/refine-spec [idea or area]` workflow discovers the project's
specification practice and gathers parallel evidence. It asks one decision at a
time, requires proposal approval, restricts writes, and verifies the result.
Calling `/refine-spec` without input audits all active specifications.

[Pi workflow reference](pi-workflows.md) defines commands, definition fields,
stages, artifacts, safety rules, and limits. [The workflow
explanation](../explanation/pi-workflows.md) describes the architecture.
[Add a project-local Pi workflow](../how-to/add-a-pi-workflow.md) gives the
authoring procedure.

## Web extensions

The module pins both extension sources as non-flake inputs:

- `pi-web-access` `v0.13.0`: `web_search`, content extraction, PDFs, GitHub,
  video handling, and its librarian skill.
- `pi-agent-browser-native` `v0.2.71`: the native `agent_browser` tool for
  JavaScript rendering and interactive browser workflows. It targets the
  installed `agent-browser` `0.32.2` release.

Pi uses `buildNpmPackage` for pi-web-access's runtime packages. The
committed `pi-web-access-package-lock.json` and `npmDepsHash` make that build
reproducible. Small generated `index.ts` files under
`~/.pi/agent/extensions/` import each extension from its immutable store path.
Home Manager links the bundled librarian skill under `~/.pi/agent/skills/`.

## Neovim ACP adapter

`flake.lock` pins the unversioned non-flake `pi-acp` input to a commit.
`buildNpmPackage` builds the input. Upstream Pi exposes `pi --mode rpc`, while
codecompanion.nvim speaks the standard Agent Client Protocol. `pi-acp` bridges
the two JSON protocols over stdio.

When the sibling home has `programs.pi.enable = true`, the nvf module enables
codecompanion.nvim. Its custom `pi` ACP adapter launches
`pi-acp`, enables embedded context, and makes Pi the default chat adapter.
CodeCompanion receives streamed messages, tool activity, file diffs, model and
thinking options, slash commands, and persistent Pi sessions. Pi continues to
execute filesystem and shell tools locally. ACP filesystem and terminal
delegation are not enabled.

## Typed-link navigation

The `typed-links` extension resolves the shared `[[type:name]]` convention
through the `follow_link` tool. Pi supports four link types:

- `skill`: loads a skill body and optional arguments.
- `command`: expands a Pi prompt template and its arguments.
- `spec`: loads a project specification.
- `doc`: loads a project documentation page.

Pi treats every other type as foreign and never guesses its targets. It ignores
typed-link examples inside Markdown code spans and fences. Pi does not implement
MCP or extension adapters.

Home Manager builds the global registry at
`~/.pi/agent/link-registry.json` from:

- Pi skills under `modules/programs/pi/config/skills/`, which hold the writing,
  comment, and documentation policies as well as the Pi-specific skills
- Pi prompt templates under `modules/programs/pi/config/prompts/`

These two roots are the only sources. The `pi-typed-links` check pins the
complete set of global resource ids. It also requires an empty scanner
diagnostic list. It then asserts that the compiler read every entry from inside
one of those roots. Any resource that Pi does not own therefore fails the check.
The manifest contains metadata and immutable source paths, not resource bodies.

The same dependency-free compiler scans these project paths after Pi trusts the
project:

- `.agents/skills/**/SKILL.md`
- `.pi/skills/**/SKILL.md`
- `.pi/prompts/*.md`
- `specs/**/*.md`
- `docs/**/*.md`

Global and project registries remain separate. Links from a registered resource
resolve inside its own layer. Pi reports an unqualified user link as ambiguous
when it matches both layers. Ordinary `read` results containing supported links
gain a compact footer with canonical targets, but no target loads automatically.

At session startup, Pi reports the global and project entry counts and the
registry diagnostic total. It uses a warning when that total is nonzero. The
total combines scanner diagnostics with malformed or missing typed-link edges.

`/links` reports registry counts, `/links unresolved` lists diagnostics,
`/links <type>:<name>` inspects one resource, and `/links reload` reloads Pi's
resources and rescans the project. Tool output follows Pi's standard truncation
limits and points to the full source path when truncated.

Home Manager installs the global `writing-pi-extensions` skill under
`~/.pi/agent/skills/`. It requires extension designs to decide whether they
introduce a durable resource kind that needs a typed-link adapter.
[Pi typed-link navigation](../explanation/pi-typed-links.md) explains the
registry's design.

## Documentation workflow

The managed `~/.pi/agent/AGENTS.md` requires Pi to load
`global:skill:documentation` before using code for high-level project
navigation. Pi reads the project's documentation first and uses code for
low-level implementation details.

The documentation skill defines these requirements:

- Existing project architecture, terms, style, and tooling take precedence.
- Diátaxis supplies the default architecture when no existing system applies.
- Missing high-level information found in code becomes a reported
  documentation gap.
- Pi corrects verified documentation errors during the same task.
- Every code change receives a documentation pass before completion.
- Each new capability receives durable documentation in the same task.
- A project without documentation receives the minimum required Diátaxis
  structure after Pi adds code.

Pi applies `global:skill:writing` before editing documentation. It runs
`pi-writing-lint` on changed Markdown and plain-text files. The global
`global:skill:diataxis` skill defines the four documentation types and their
placement rules.

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
default scope is comments added, deleted, or modified in `git diff HEAD`. A
supplied path or range replaces that default. Naming a file reviews every
comment in it. The workflow changes comments only, works deletion-first, and
preserves functional directives and legal or generated provenance verbatim.

## Managed policy

Home Manager owns two focused policy files:

- `~/.pi/web-search.json` selects Exa, disables the interactive curator with
  `workflow = "none"`, and forbids browser-cookie extraction. This makes
  unattended runs return raw evidence to the main agent.
- `~/.pi/config/pi-agent-browser-native/config.json` disables that extension's
  companion search tool. pi-web-access owns search. `agent_browser` remains the
  JavaScript-capable fallback.

API keys are not stored in Nix. pi-web-access reads `EXA_API_KEY`,
`BRAVE_API_KEY`, and its other supported provider variables from the process
environment. Add credentials through sops-nix when needed.

Nix does not manage Pi's authentication, model catalog, or session state. The
module also leaves `~/.pi/agent/settings.json` mutable except for `shellPath`.
A Home Manager activation merges that key into the live JSON when the home
enables Fish. It removes only that key when the home disables Fish. Users can
change every other setting through `/settings`.

The activation refuses malformed JSON and symbolic links instead of replacing
them. Do not save `/settings` during home activation because Pi and Home Manager
do not share a settings lock. A trusted project's `.pi/settings.json` can
override the global shell path.

The managed path names the Fish package selected by Home Manager. Pi starts
Fish non-interactively, so normal shell initialization and autoloaded functions
such as `nr` remain available. Interactive aliases, prompts, completions,
keybindings, and plugin setup remain inactive. The generated global context
tells Pi to use Fish syntax only when the home enables Fish. Existing Pi
processes require a restart after home activation to read the changed setting.

The module owns the extension entry points, global context, link manifest,
prompts, writing linter, and focused skill links. It also owns the two web policy
files above.

## The numtide cache aspect

`flake.modules.generic.numtide-cache`, in the same file, appends
`https://cache.numtide.com` and its trusted key to the daemon settings. Hosts
import it at system scope. Homes never do. It reaches the daemon on the next
system rebuild.
