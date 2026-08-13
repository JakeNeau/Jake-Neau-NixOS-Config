# Pi workflows

Pi loads the global workflow manager from
`modules/programs/pi/extensions/workflows/`. Home Manager installs its entry
point at `~/.pi/agent/extensions/workflows/index.ts`.

## Modes and commands

`Shift+Tab` cycles through `normal` and every discovered workflow. Selecting a
workflow arms it. The next submitted prompt becomes that workflow's input.

Home Manager binds `app.thinking.cycle` to `Ctrl+Shift+L`, because the workflow
manager owns `Shift+Tab`. This binding avoids macOS's native `Ctrl+Tab` tab
shortcut and remains distinct from Ghostty and niri shortcuts.

Each global workflow can register a direct command. The bundled workflows use
`/refine-spec [idea or area]` and
`/refine-plan [specification or area]`. Project workflow commands pass through
the input router and appear in workflow autocomplete.

`/workflow` supports these forms:

| Command | Behavior |
|---|---|
| `/workflow` | Select and arm a mode |
| `/workflow <name>` | Arm a workflow |
| `/workflow <name> <input>` | Start a workflow |
| `/workflow run <name> [input]` | Start a workflow directly |
| `/workflow status` | Show the armed or running workflow |
| `/workflow stop` | Abort the running workflow |
| `/workflow restart [input]` | Start the last workflow as a new run |

Only one workflow can run at a time. A completed or stopped workflow returns Pi
to `normal`. Pi does not support cross-session workflow resume.

## Definition locations

Pi loads definitions from:

- the immutable global workflow tree beside the extension source
- `.pi/workflows/<name>/` in a trusted project or trusted ancestor

A definition directory contains:

```text
<name>/
  workflow.json
  stages/*.md
  schemas/*.json
```

Project definitions load only when `ctx.isProjectTrusted()` is true. A project
workflow can replace a global workflow only with an explicit `replaces` field.
Pi reports invalid definitions and accidental name collisions.

A trusted project may define read-only Bash exceptions at
`.pi/workflows/read-only-exceptions.json`. The policy has this structure:

```json
{
  "version": 1,
  "workflows": {
    "refine-spec": {
      "verify": {
        "allowedCommandPrefixes": ["nix flake check", "cargo test"]
      }
    }
  }
}
```

Each exception applies to one existing read-only stage that enables `bash`.
Commands may equal an approved prefix or add arguments after it. Pi still
blocks newlines, redirection, command substitution, and shell composition. An
invalid policy rejects every exception in that file and produces a
workflow diagnostic. Untrusted projects receive no exceptions.

A workflow cannot set a model, provider, or thinking level. Pi snapshots the
user's active model and thinking level when the run starts. Every child stage
uses that snapshot.

## Stage definition

Each stage in `workflow.json` defines:

| Field | Meaning |
|---|---|
| `prompt` | Markdown prompt path relative to the workflow directory |
| `tools` | Exact child tool allowlist before Pi adds workflow artifact tools |
| `readOnly` | Whether the child enforces read-only tool and Bash policy |
| `inputs` | Artifact kinds that Pi includes in the stage prompt |
| `outputSchema` | Portable JSON schema for `workflow_output` |
| `transitions` | Output outcomes mapped to allowed successor sets |
| `join` | Optional `all` or `any` branch join |
| `mutationPaths` | Required marker for mutation stages |
| `checkpoint` | Optional `question` or `proposal` user checkpoint |

A successor set is an array of stage names. A transition may offer several
sets. Pi runs a router child to select among them. Several names in one set form
a fork. An empty transition list ends the workflow for that outcome.

Read-only fork branches may run concurrently. `maxParallel` limits the run.
Mutation and user-decision stages run serially.

## Child stages

Each non-conversation stage uses a fresh `pi --mode rpc --no-session` process.
A refinement conversation keeps one child process for that mode. The child
receives the project directory, trust decision, model snapshot, thinking
snapshot, stage prompt, selected artifacts, artifact catalog, and tool
allowlist.

The workflow extension detects `PI_WORKFLOW_CHILD=1` and registers two tools:

- `workflow_output` validates and terminates the stage with its required
  artifact.
- `request_workflow_artifacts` loads up to three earlier artifacts from the
  current run, with a combined 50 KB limit.

The parent validates `workflow_output` again. Invalid or missing output receives
one correction prompt in the same child process. A second failure stops that
stage.

Stage context uses compact JSON. When synthesis evidence still exceeds 50 KB,
Pi first removes source excerpts. Pi then applies bounded evidence projections
if needed and continues with the first projection that fits. The original
artifacts remain unchanged in the session. This recovery applies to both
`refine-spec` and `refine-plan`.

Escape, `/workflow stop`, reload, and session shutdown abort active RPC work and
clean up temporary files and processes.

## Artifacts

The parent assigns every artifact a run identity, stage invocation identity,
parent artifact identities, timestamp, kind, outcome, summary, and payload.
Parents must already exist. This rule keeps the concrete artifact graph acyclic
even when stage types repeat.

Pi stores artifacts as custom session entries. They do not enter the parent LLM
context. The TUI renders compact entries and exposes payloads when the user
expands tool output.

Declared artifact kinds enter a child prompt automatically. The child receives
only metadata for other artifacts until it calls
`request_workflow_artifacts`.

## Mutation policy

Read-only stages block `edit`, `write`, and Bash outside a conservative
inspection-command policy. Definitions may use `read`, `grep`, `find`, `ls`,
`bash`, `follow_link`, `rust_code`, `web_search`, `fetch_content`, and
`get_search_content` in read-only stages. A trusted project policy may add
stage-scoped Bash command prefixes, including prefixes denied by the default
policy. These exceptions do not permit `edit`, `write`, other tools, or shell
composition.

Mutation definitions may add `edit` and `write`, but they cannot use Bash or
unknown custom tools. Mutation stages receive exact approved paths and block
edits elsewhere. The bundled `refine-spec` writer receives no Bash tool.

Both refinement workflows hash approved files before writing. A workflow stops
if a file changes between approval and mutation. Built-in edit and write tools
retain Pi's shared file-mutation queue behavior.

## `refine-spec`

`/refine-spec <text>` classifies text as a new idea or a focus area.
`/refine-spec` runs a full audit. An ambiguous input produces a user choice.

The workflow discovers the project's specification practice from documentation
before code. One canonical location may contain many specification files. When
several locations exist, Pi chooses the documented authority and warns that the
project should consolidate specification tracking.

In audit mode, Pi ranks contradictions, ambiguity, missing decisions,
architecture conflicts, implementation conflicts, implementation gaps, and
acceptance gaps.
It handles one issue at a time and reruns the audit after a verified write.
Issue fingerprints suppress unchanged issues that the user skips or resolves in
the current run.

Pi refines each issue in these phases:

1. Four read-only children inspect specifications, documentation,
   implementation, and verification evidence.
2. A join stage synthesizes their artifacts.
3. The user selects clarification, exploration, or writing.
4. Clarification uses one persistent child that asks one focused question at a
   time.
5. Exploration uses one persistent child for a user-led design conversation.
6. The user explicitly requests every switch between clarification,
   exploration, and writing.
7. A proposal stage integrates the evidence and conversation summaries.
8. The user approves exact specification files before mutation.
9. A writer changes only those files.
10. A fresh verifier checks the proposal, decisions, architecture, and project
    validation.

Clarification and exploration are separate modes. Clarification lets the model
lead requirement discovery. Exploration lets the user lead an open discussion.
The child cannot switch modes or start writing.

The conversation editor accepts these stage commands:

| Command | Result |
|---|---|
| `/clarify` | Finalize the current conversation and enter clarification |
| `/explore` | Finalize the current conversation and enter exploration |
| `/write` | Finalize the current conversation and prepare the proposal |
| `/stop` | Stop the workflow without writing |

An explicit natural-language instruction can also change the stage. Examples
include `Switch to clarification mode`, `Please enter explore mode`, and
`Start writing the specification`. A discussion statement such as `I think we
can write this now` remains part of the current conversation. Questions and
suggestions also remain in the current mode.

A conversation child remains alive across its turns. This preserves normal chat
context and avoids a new Pi process and repeated evidence prompt for every
message. When the user requests a stage change, the child emits one bounded
`conversation-summary` artifact. The next stage receives that summary instead
of the full transcript.

The writer gets one correction attempt after failed semantic verification. A
second failure stops the workflow.

Before approval, Pi checks every proposed mutation target against the canonical
specification location. An invalid target records a `corrective-action` artifact
and sends it to a fresh proposal stage. The workflow continues when the corrected
proposal is valid. A second invalid proposal stops the workflow without mutation.

## `refine-plan`

`/refine-plan <text>` selects a specification or existing plan to refine.
`/refine-plan` audits all active plans. Ambiguous input produces a user choice.

The workflow searches the canonical specification root recursively. The
repository convention permits subdirectories at any depth. Each plan must stay
in the same directory as its specification. The workflow does not impose a
filename convention. It asks the user when the association or target path is
ambiguous.

`refine-plan` uses the same discovery, audit, parallel investigation,
synthesis, conversation, approval, mutation, retry, and verification control
flow as `refine-spec`. Its stage prompts apply implementation-plan constraints.

The workflow reads project documentation before broad code. Four investigation
branches gather specification, documentation, implementation, and verification
evidence. Clarification asks about unresolved implementation choices.
Exploration remains user-led. Only the user can switch stages.

The approved plan is high-level pseudocode. It names exact file paths, symbols,
interfaces, behavior, data flow, errors, compatibility work, tests, validation,
and documentation. A verifier rejects any plan that leaves a coding decision
unresolved. The mutation boundary permits one approved plan file and rejects a
path outside the specification's directory.

## Limits

Prompts and artifact requests use Pi's 50 KB and 2,000-line limits. Synthesis
stages compact oversized evidence as described above. Other oversized stage
inputs stop the workflow. A generic workflow run stops after 100 stage
invocations. Project workflow schemas use a portable subset of JSON Schema and
cannot use unsupported provider constructs.
