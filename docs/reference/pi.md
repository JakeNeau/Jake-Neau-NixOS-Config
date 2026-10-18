# The pi module

`modules/programs/pi/pi.nix`: the `flake.programs.pi` declaration installing
and configuring the `pi` coding agent per user. It supplies two web
capabilities: structured research through **pi-web-access**, and real-browser
fallback through **pi-agent-browser-native** plus the `agent-browser` CLI. It
also installs `pi-subagents` for child-agent delegation and the `pi-acp` adapter
used by Neovim. Why pi, and why it routes per user:
[coding agents](../explanation/coding-agents.md).

## The declaration

- `install.linux = ["home"]`, `install.macos = ["home"]`: per-user on both
  platforms. Delivered by `flake.users.jakeneau.programs`.
- `hasEnableOption = false` + `packages`: the generator supplies the enable
  toggle and installs both pi and `agent-browser` behind it.
- Pi comes from `inputs.llm-agents.packages.<system>.pi`, via
  **llm-agents.nix** (`github:numtide/llm-agents.nix`). The input deliberately
  does not follow this flake's nixpkgs. The module patches the packaged
  JavaScript and rebuilds the Bun executable locally with cached npm
  dependencies.
- `agent-browser` also comes from llm-agents.nix. It updates with Pi, so the
  CLI and `pi-agent-browser-native` stay on current upstream releases.

## Transcript modes

The patched Pi package and `minimal-transcript` extension start each interactive
session in minimal mode. This mode shows user prompts, file diffs, workflow
proposal reviews, final assistant responses, and Pi's native transient status row.
The footer remains visible, including custom footers and persistent extension statuses.
Pi hides startup notices, thinking, intermediate assistant messages, tool calls,
tool results, unrelated custom entries, and the header.
Dialogs and the editor remain available.

The status row shows Pi's animated spinner while an agent turn is active. A turn
starts with `Thinking…`, and assistant text streaming changes the label to
`Writing response…`. Before each tool batch, the agent writes one plain-text
activity line in the same assistant message. The extension shows a valid line
beside the spinner while the batch runs.

A line must describe current activity rather than hidden reasoning and use no
more than 48 visible columns. A missing or invalid line produces `Working…`.
Retry countdowns, context compaction, and branch summarization use Pi's native
transient indicators in the same row. The row disappears when Pi settles.

`Alt+T` switches between minimal mode and normal Pi output. The switch updates
the complete current transcript and working label, including content produced
before or during an active response. Full mode shows progress lines as normal
assistant text and uses Pi's default working message. It follows Pi's normal
thinking-block and tool-expansion settings.

A new, resumed, forked, or replaced session starts in minimal mode. The activity
row is TUI-only. RPC, print, and JSON modes remain unchanged.

The extension records successful `edit` and `write` calls as durable custom
entries.

Each entry opens as a colored unified diff in minimal mode. Full mode hides
these synthetic entries because normal Pi already renders the underlying tool
calls.

`Alt+O` expands or collapses file diffs in minimal mode and normal tool output
in full mode. `Ctrl+O` and `Ctrl+Shift+O` are unbound. Pi retains `Ctrl+T` for
thinking-block visibility in full mode.

Both shortcuts are application-wide in TUI mode. They remain active while
selectors, custom tool dialogs, loaders, and overlays own keyboard focus.

The minimal filter applies to every tool renderer, including tools from
third-party extensions. Diff capture is narrower because only `edit` and
`write` expose a bounded text-file mutation contract. File changes made through
`bash` or another custom tool do not produce diff entries.

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

The TUI shows the highlighted option's preview in a bordered Markdown panel.
The panel has a 16-line content viewport. When the rendered preview overflows,
a right-edge scrollbar shows the current position. `Ctrl+Alt+J` scrolls down by
one line, and `Ctrl+Alt+K` scrolls up by one line. Holding either key repeats the
movement. Changing the highlighted option resets the preview to its first line.

Arrow keys remain dedicated to option selection. The help row shows the preview
controls only while the selected preview overflows.

The extension does not support physical mouse-pointer hover because Pi's
extension TUI API does not expose mouse events.

The dialog always includes actions for a free-form answer and a clarifying
question. Selecting either action turns that row into a one-line input. The
question and every other option remain visible while the user types. Escape or
an empty submission restores the action label. A nonempty free-form answer
completes the tool call.

A clarifying question leaves the original decision pending. The agent answers
the clarification first. The extension then reopens the original dialog unless
the agent already called `ask_user` again. An answer or cancellation clears the
pending question.

The custom inline dialog, previews, and preview scrolling work only in TUI mode.
RPC mode uses Pi's separate selection and input dialogs. It accepts the same
option objects and does not render previews. In print and JSON modes, the tool
directs the agent to ask through normal text. The extension does not support
multiple selections or multiple questions in one call.

## Prompt tuning

The global `tune` extension registers the `/tune <draft>` command. The command
turns a draft prompt into a tuned prompt through an exchange with the agent.
After the user accepts the result, Pi removes the exchange from the model
context and submits the tuned prompt.

`/tune` works only in interactive mode. Pi rejects the command in these cases
and leaves the session unchanged:

- The draft is blank. Pi shows `Usage: /tune <draft prompt>`.
- Pi runs in RPC, print, or JSON mode.
- The agent is busy, or Pi has queued messages.
- Another `/tune` run is active.

The agent receives the draft with tuning instructions from
`modules/programs/pi/extensions/tune/instructions.md`. The agent also sees the
existing conversation. It reads the project's agent instructions and
documentation before code, and it answers repository questions from evidence.
It asks the user one material question per turn through `ask_user`. It does no
implementation work.

The agent ends each run with a `propose_prompt` call. The proposal must stand
alone without the exchange. It names the relevant files, documentation, and
skills, and it states constraints and success criteria. Outside a `/tune` run,
`propose_prompt` returns an error.

Pi shows the proposal with four choices:

- **Accept:** Pi rewinds the session and submits the proposal as the next user
  message.
- **Edit:** The user changes the proposal in an editor. Pi then shows the
  choices again. A blank edit keeps the earlier proposal.
- **Keep tuning:** The user enters feedback, and the agent produces a new
  proposal. Pi then shows the choices again. Blank feedback starts no run.
- **Cancel:** Pi rewinds the session and submits nothing. Escape has the same
  effect.

If a run ends without a proposal, Pi rewinds the session and submits nothing.
Pi then warns that the agent proposed no prompt. An agent question in plain
text causes this result.

The rewind uses no branch summary. It restores the model context from before
`/tune`, including an empty session. The rewind also keeps the editor text that
the user had before it. The exchange remains in the session tree as an
abandoned branch, and `/tree` can open it.

The instructions live in the extension directory instead of a skill. Pi lists
every skill in each session's startup context, so a skill would add that cost
to every session.

The `pi-tune` flake check runs the extension's unit tests. It also confirms
that the packaged Pi registers the `tune` command in RPC mode.

## Workflow manager

The `workflows` extension adds exclusive, artifact-driven workflow modes.
`Shift+Tab` cycles through `normal` and discovered workflows. Home Manager moves
Pi's thinking-level cycle to `Ctrl+Shift+L`.

Each agent stage runs in a fresh RPC child process with the user's selected
model and thinking level. The parent session stores validated stage artifacts as
non-context custom entries. Global workflows live with the extension. Trusted
projects may add declarative definitions under `.pi/workflows/`.

The bundled `/refine-spec [idea or area]` workflow reads the relevant project
evidence and proposes exact specification edits. The user approves the design
and file list before a bounded writer applies it. With no input, the workflow
selects one clear specification defect.

The bundled `/refine-plan [specification or area]` workflow proposes one concise
implementation plan. The plan names required files, symbols, behavior, data
flow, errors, tests, and documentation changes. Pi keeps the complete proposal
visible while the user approves one plan file before Pi writes it.

Each bundled refinement workflow uses one proposal stage and one writer stage.
It has no separate audit, conversation, retry, or verification pass.

[Pi workflow reference](pi-workflows.md) defines commands, definition fields,
stages, artifacts, safety rules, and limits. [The workflow
explanation](../explanation/pi-workflows.md) describes the architecture.
[Add a project-local Pi workflow](../how-to/add-a-pi-workflow.md) gives the
authoring procedure.

## Brainstorming skill

The global `brainstorming` skill turns an idea into an approved specification
before implementation. Pi inspects project evidence, asks one material question
at a time through `ask_user`, compares viable approaches, and validates the
design at proportionate checkpoints.

The skill blocks implementation until the design receives explicit approval.
It then writes only the design section in the project's specification format,
reviews that file, and requests file approval. In this repository it creates a
short-named file under `specs/` with `Spec`, `Plan`, and `Tasks` sections. The
last two remain empty for the `/refine-plan` workflow.

## OpenPencil integration

The Pi home installs the `openpencil` extension when a home requests Pi and
OpenPencil. The extension lazily starts OpenPencil's stdio MCP client and exposes
one `openpencil` tool. The tool searches the upstream MCP catalog or calls one
exact operation against the trusted project.

Read operations run without a prompt. Every mutation requires interactive user
approval. Noninteractive modes reject mutations. File arguments must remain
inside the trusted project. `save_file` joins Pi's exact-path mutation queue.
The extension disables the unrestricted OpenPencil `eval` operation and stops
its MCP child during session shutdown.

The OpenPencil program installs the desktop editor, headless `openpencil` CLI,
`openpencil-mcp`, and `openpencil-mcp-http`. The MCP process receives the
current trusted project as `OPENPENCIL_MCP_ROOT`. The desktop app must be open
with a document loaded for live canvas operations.

The global `ui-system-initializer` skill guides initialization through product
direction, hierarchy, visual foundations, reusable patterns, and verified
OpenPencil resources. It creates a project-local `ui-system` skill only after
fresh CLI verification succeeds. Initialization stops before feature UI design.
[UI system initialization](../explanation/ui-system-initialization.md) explains
this boundary and the independent verification requirement.

## Extension updates

Each GitHub extension input follows its repository's default branch.
`nix flake update` moves these inputs with llm-agents.nix, so `nr` updates them
with Pi. Each build reads its version from the extension's `package.json`.

`pi-usage-limits` is the exception. It exists only as an npm tarball, and the
tarball URL names version `0.1.4`. A new release requires a URL change.

An upstream `pi-usage-bar` change can stop the context-warning patch from
applying. The home build then fails.

## Web extensions

Both extension sources are non-flake inputs:

- `pi-web-access`: `web_search`, content extraction, PDFs, GitHub,
  video handling, and its librarian skill.
- `pi-agent-browser-native`: the native `agent_browser` tools for JavaScript
  rendering and interactive browser workflows.

Nix builds both with `buildNpmPackage` from each upstream `package-lock.json`.
The builds need no hash in this repository. Nix compiles
`pi-agent-browser-native` to `dist/`. Nix removes pi-web-access's development
packages and its copies of the libraries Pi supplies. Small generated
`index.ts` files under `~/.pi/agent/extensions/` import each extension from its
immutable store path.
Home Manager links the bundled librarian skill under `~/.pi/agent/skills/`.

## Subagents

`pi-subagents` is a non-flake input. Nix installs
its runtime dependencies from the upstream lockfile without development
packages or physical copies of the libraries Pi supplies.

Home Manager installs a store-backed entry point at
`~/.pi/agent/extensions/subagent/index.ts`. The package discovers its bundled
agents from its immutable store directory. User and trusted-project agent
definitions can override bundled agents.

The bundled roles include `scout`, `researcher`, `evidence-auditor`, `worker`,
`reviewer`, `oracle`, and `delegate`. The research roles use the installed
`pi-web-access` extension. Foreground children run inside the parent Pi
process. Background children use a detached runner. Upstream fully validates
standalone background execution only with official Pi 0.86.1 on Linux x64.
This Nix package is outside that support target.

Home Manager also links the `pi-subagents` and `council-mode` skills and all
six bundled prompt templates. The templates add `/council`,
`/gather-context-and-clarify`, `/parallel-cleanup`, `/parallel-research`,
`/parallel-review`, and `/review-loop`.

The extension registers these management commands:

- `/subagents` lists available agents.
- `/subagents-guide [topic]` opens the installed reference.
- `/subagents-doctor` checks the setup.
- `/subagents-fleet` inspects active children.

Installing the extension does not start agents or enable automatic reviews.
Delegation requires a user request or applicable instructions. Model selection,
agent overrides, and other subagent settings remain user-owned. Pi's mutable
`settings.json` contains no package declaration for this extension.

The `pi-third-party-extensions` flake check loads every third-party extension
with the packaged Pi executable. Pi fails the check when an extension does not
load. The check also verifies command registration. It also checks bundled resources and the absence
of physical host-library copies. It does not make model requests or validate
background execution.

## Provider and usage extensions

Five more third-party extension sources are non-flake inputs. Home
Manager writes store-backed entry points under `~/.pi/agent/extensions/`.
Pi's mutable `settings.json` contains no package declarations for them.

- `pi-anthropic-auth` shapes Anthropic OAuth requests while leaving API
  key requests unchanged.
- Pi uses `pi-claude-bridge` to expose Claude Code models.
  Pi registers those models under `claude-bridge`.
  Nix builds the runtime dependencies.
  Nix removes physical copies of the libraries Pi supplies.
- `pi-usage` reports provider quota through a usage command.
- `pi-usage-bar` records local token and cost events, adds usage
  reports, and supplies the only custom footer. The footer remains visible in
  both transcript modes. Its context gauge shows the
  [context warning levels](#context-warning-levels).
- `pi-usage-limits` publishes the active model's subscription limits as
  the `model-usage` extension status. Claude models from any provider show
  five-hour and seven-day utilization. Codex models show the short and weekly windows that
  the provider reports. Unsupported models and request failures remain visible
  as extension statuses.

`pi-usage-limits` refreshes at session startup, after model changes, and after
agent runs settle. Refreshes run only in TUI mode and do not block Pi. A shared
60-second disk cache at `~/.pi/agent/cache/pi-usage-limits.json` limits requests
across concurrent Pi sessions.

The build patches the Claude quota query to use Pi's `anthropic` login. Upstream
runs the Claude Agent SDK, which needs a separate Claude Code login. The patch
sends the Pi OAuth token to the `api/oauth/usage` endpoint that Claude Code
calls. Anthropic does not document that endpoint, so the patch may need an
update after an API change. If Pi has no Anthropic login, the status shows
`Claude: run /login anthropic`.

`pi-usage-bar` renders the status through its `extensions` footer segment. It
removes status colors and truncates each extension status to 28 visible columns.
The quota extension does not replace the footer or alter RPC, print, and JSON
behavior.

`pi-usage` and `pi-usage-bar` both register `usage`. Pi disambiguates the
commands as `usage:1` and `usage:2`.

### Context warning levels

The footer's context gauge tells the user when to start a new session. Pi does
not compact automatically, so these levels replace that safeguard. The level
depends on the share of the context window in use:

| Used context | Gauge color | Warning text |
|---|---|---|
| below 20% | green (`success`) | none |
| 20% to below 50% | yellow (`warning`) | `consider new session` |
| 50% and above | red (`error`) | `start new session` |

- The levels use the unrounded percentage. A context at 49.6% displays `50%`
  but stays yellow.
- Each boundary takes the higher level. Exactly 20% is yellow, and exactly 50%
  is red.
- The warning text follows the gauge inside the context segment and has the
  gauge color, for example `███░░░░░░░ 34% (200k) consider new session`.
- Footer truncation removes the end of the line first. Later segments therefore
  disappear before the warning text.
- When Pi reports no usage, the gauge stays muted and shows no warning text.
- Other footer segments keep their upstream colors.

Nix builds `pi-usage-bar` with a context-warning patch. The build also runs a
footer test, which fails the build when a level renders the wrong color or
text.

Home Manager activation sets `warningThreshold` to 20 and `errorThreshold` to
50 in `~/.pi/agent/pi-usage-bar/config.json`. It preserves the other keys. The
file stays mutable because `/usage` commands save their settings there. A saved
config overrides the upstream defaults, so a patched default alone would not
set the levels. A `/usage` change to either threshold lasts only until the next
activation.

Home Manager activation merges the Nix `claude` executable path into
`~/.pi/agent/claude-bridge.json`. The file stays mutable so Claude Bridge can
record notice fields and users can set other bridge options.

## Neovim ACP adapter

`buildNpmPackage` builds the non-flake `pi-acp` input. Upstream Pi exposes `pi --mode rpc`, while
codecompanion.nvim speaks the standard Agent Client Protocol. `pi-acp` bridges
the two JSON protocols over stdio.

For homes with Pi enabled, the nvf module activates the CodeCompanion plugin.

The custom `pi` ACP adapter launches `pi-acp` with embedded context enabled. Pi
is the default chat adapter.

CodeCompanion receives streamed messages, tool activity, file diffs, model and
thinking options, slash commands, and persistent Pi sessions.

`<leader>an` creates a new chat, while `<leader>at` toggles the most recent chat.
`<leader>ab` attaches the current buffer as CodeCompanion context instead of
copying its text into the chat. Pi continues to execute filesystem and shell
tools locally. ACP filesystem and terminal delegation are not enabled.

## Typed-link navigation

The `typed-links` extension resolves the shared `[[type:name]]` convention
through the `follow_link` tool. Pi supports four link types:

- `skill`: loads a skill body and optional arguments.
- `command`: expands a Pi prompt template and its arguments.
- `spec`: loads a project specification.
- `doc`: loads a project documentation page.

Pi treats every other type as foreign and never guesses its targets. It ignores
typed-link examples inside Markdown code spans and fences. OpenPencil resources
remain ordinary project paths and identifiers rather than typed-link resources.

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

Home Manager installs the global `brainstorming`, `writing-pi-extensions`, and
`ui-system-initializer` skills under `~/.pi/agent/skills/`. Extension designs
must decide whether they introduce a durable resource kind that needs a
typed-link adapter.
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

Home Manager owns the following focused policy and integration files:

- `~/.pi/agent/mcp.json` conditionally registers the Home Assistant MCP server.
  `programs.home-assistant.enableMcpIntegration` controls this file. Linux also
  requires `programs.home-assistant.enable`. When
  `programs.home-assistant-filesystem.enable` is active, the same file adds a
  filesystem MCP server rooted at `/mnt/home-assistant-www`. Home Manager does
  not manage the OAuth tokens in `~/.pi/agent/mcp-auth.json`. See the [Home
  Assistant control app](home-assistant.md).
- `~/.pi/web-search.json` selects Exa, disables the interactive curator with
  `workflow = "none"`, and forbids browser-cookie extraction. This makes
  unattended runs return raw evidence to the main agent.
- `~/.pi/config/pi-agent-browser-native/config.json` disables that extension's
  companion search tool. pi-web-access owns search. `agent_browser` remains the
  JavaScript-capable fallback.

API keys are not stored in Nix. pi-web-access reads `EXA_API_KEY`,
`BRAVE_API_KEY`, and its other supported provider variables from the process
environment. Add credentials through sops-nix when needed.

Nix does not manage Pi's authentication, model catalog, or session state. Each
machine with the integration enabled authenticates once with
`pi mcp login home-assistant`. The module also leaves
`~/.pi/agent/settings.json` mutable except for `shellPath` and
`compaction.enabled`. Users can change every other setting through
`/settings`.

A Home Manager activation merges `shellPath` into the live JSON when the home
enables Fish. It removes only that key when the home disables Fish.

A second activation always sets `compaction.enabled` to `false`. It preserves
the other `compaction` keys. The setting has these effects:

- Pi never compacts at the size threshold.
- Pi skips its compact-and-retry recovery on context overflow. A full context
  therefore shows a provider error.
- Manual `/compact` remains available.

The [context warning levels](#context-warning-levels) prompt a new session
before the context fills. A `/settings` change to `compaction.enabled` lasts
only until the next activation. Existing Pi processes require a restart after
activation to read the key.

Each activation that edits Pi JSON refuses malformed JSON and symbolic links
instead of replacing them. This rule covers the shell, compaction, Claude
Bridge, and usage-bar threshold activations. Do not save `/settings` or
`/usage` changes during home activation because Pi and Home Manager do not
share a lock. A trusted project's `.pi/settings.json` can
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
