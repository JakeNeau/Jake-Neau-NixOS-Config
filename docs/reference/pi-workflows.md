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
| `tools` | Exact child tool allowlist before workflow artifact tools are added |
| `readOnly` | Whether the child enforces read-only tool and Bash policy |
| `inputs` | Artifact kinds included in the stage prompt |
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

Each stage uses a fresh `pi --mode rpc --no-session` process. The child receives
the project directory, trust decision, model snapshot, thinking snapshot, stage
prompt, selected artifacts, artifact catalog, and tool allowlist.

The workflow extension detects `PI_WORKFLOW_CHILD=1` and registers two tools:

- `workflow_output` validates and terminates the stage with its required
  artifact.
- `request_workflow_artifacts` loads up to three earlier artifacts from the
  current run, with a combined 50 KB limit.

The parent validates `workflow_output` again. Invalid or missing output receives
one correction prompt in the same child process. A second failure stops that
stage.

Escape, `/workflow stop`, reload, and session shutdown abort active RPC work and
clean up temporary files and processes.

## Artifacts

The parent assigns every artifact a run identity, stage invocation identity,
parent artifact identities, timestamp, kind, outcome, summary, and payload.
Parents must already exist. This rule keeps the concrete artifact graph acyclic
even when stage types repeat.

Pi stores artifacts as custom session entries. They do not enter the parent LLM
context. The TUI renders compact entries and exposes payloads when tool output
is expanded.

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

Audit mode ranks contradictions, ambiguity, missing decisions, architecture
conflicts, implementation conflicts, implementation gaps, and acceptance gaps.
It handles one issue at a time and reruns the audit after a verified write.
Issue fingerprints suppress unchanged issues that the user skips or resolves in
the current run.

Each refinement performs these phases:

1. Four read-only children inspect specifications, documentation,
   implementation, and verification evidence.
2. A join stage synthesizes their artifacts.
3. Fresh elicitation stages ask one multiple-choice question at a time.
4. Clarification stages answer user questions without recording decisions.
5. A proposal stage integrates the evidence and recorded answers.
6. The user approves exact specification files before mutation.
7. A writer changes only those files.
8. A fresh verifier checks the proposal, decisions, architecture, and project
   validation.

In TUI mode, multiple-choice checkpoints use the same inline dialog as the
`ask_user` tool. Selecting the free-form or clarification action replaces only
that action row with an input. The question and all options remain visible.

The writer gets one correction attempt after failed semantic verification. A
second failure stops the workflow.

## `refine-plan`

`/refine-plan <text>` selects a specification or existing plan to refine.
`/refine-plan` audits all active plans. Ambiguous input produces a user choice.

The workflow searches the canonical specification root recursively. The
repository convention permits subdirectories at any depth. Each plan must stay
in the same directory as its specification. The workflow does not impose a
filename convention. It asks the user when the association or target path is
ambiguous.

`refine-plan` uses the same discovery, audit, parallel investigation,
synthesis, decision, approval, mutation, retry, and verification control flow
as `refine-spec`. Its stage prompts apply implementation-plan constraints.

The workflow reads project documentation before broad code. Four investigation
branches gather specification, documentation, implementation, and verification
evidence. The elicitation loop asks one question for every unresolved
implementation choice.

The approved plan is high-level pseudocode. It names exact file paths, symbols,
interfaces, behavior, data flow, errors, compatibility work, tests, validation,
and documentation. A verifier rejects any plan that leaves a coding decision
unresolved. The mutation boundary permits one approved plan file and rejects a
path outside the specification's directory.

## Limits

Prompts and artifact requests use Pi's 50 KB and 2,000-line limits. A generic
workflow run stops after 100 stage invocations. Project workflow schemas use a
portable subset of JSON Schema and cannot use unsupported provider constructs.
