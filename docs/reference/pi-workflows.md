# Pi workflows

Pi loads the workflow manager from
`modules/programs/pi/extensions/workflows/`. Home Manager installs its entry
point at `~/.pi/agent/extensions/workflows/index.ts`.

## Modes and commands

`Shift+Tab` cycles through `normal` and every discovered workflow. Selecting a
workflow arms it. The next submitted prompt becomes that workflow's input.

Home Manager binds `app.thinking.cycle` to `Ctrl+Shift+L`, because the workflow
manager owns `Shift+Tab`.

The bundled workflows register `/refine-spec [idea or area]` and
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
| `/workflow stop` | Stop the running workflow |
| `/workflow restart [input]` | Start the last workflow as a new run |

Only one workflow can run at a time. A completed or stopped workflow returns Pi
to `normal`. Pi does not resume workflows across sessions.

## Definition locations

Pi loads definitions from:

- the global workflow tree beside the extension source
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
Pi reports invalid definitions and name collisions.

A trusted project may define read-only Bash exceptions at
`.pi/workflows/read-only-exceptions.json`:

```json
{
  "version": 1,
  "workflows": {
    "review-change": {
      "inspect": {
        "allowedCommandPrefixes": ["nix flake check", "cargo test"]
      }
    }
  }
}
```

Each exception applies to one existing read-only stage that enables `bash`.
Commands may equal an approved prefix or add arguments. Pi blocks shell
composition. An invalid policy rejects every exception in that file.

A workflow cannot set a model, provider, or thinking level. Pi snapshots the
active model and thinking level when the run starts.

## Stage definitions

Each stage in `workflow.json` defines:

| Field | Meaning |
|---|---|
| `prompt` | Markdown prompt path relative to the workflow directory |
| `tools` | Exact child tool allowlist |
| `readOnly` | Whether the child enforces read-only policy |
| `inputs` | Artifact kinds included in the stage prompt |
| `outputSchema` | Portable JSON schema for `workflow_output` |
| `transitions` | Output outcomes mapped to allowed successor sets |
| `join` | Optional `all` or `any` branch join |
| `mutationPaths` | Required marker for mutation stages |
| `checkpoint` | Optional `question` or `proposal` user checkpoint |

A successor set is an array of stage names. A transition may offer several
sets. Pi asks a router child to select among them. Several names in one set form
a fork. An empty transition list ends the workflow for that outcome.

Read-only branches may run concurrently. `maxParallel` limits the run. Mutation
and user-decision stages run serially.

## Child stages and artifacts

Each stage uses a fresh `pi --mode rpc --no-session` child process. The child
receives the project directory, trust decision, model snapshot, stage prompt,
selected artifacts, artifact catalog, and tool allowlist.

The child process registers two workflow tools:

- `workflow_output` validates and returns the stage artifact.
- `request_workflow_artifacts` loads up to three earlier artifacts within a
  combined 50 KB limit.

The parent validates `workflow_output` again. Invalid or missing output receives
one correction prompt. A second failure stops the stage.

The parent assigns each artifact a run identity, stage identity, parent
identities, timestamp, kind, outcome, summary, and payload. Parents must already
exist. Pi stores artifacts as non-context session entries. The TUI shows a
compact entry and reveals the payload when expanded.

Escape, `/workflow stop`, reload, and session shutdown abort active work and
clean up temporary files and processes.

## Mutation policy

Read-only stages block `edit`, `write`, and Bash outside the inspection-command
policy. A trusted project policy may add stage-scoped Bash prefixes.

Mutation stages may use `edit` and `write`. They cannot use Bash or unknown
custom tools. A proposal checkpoint shows the design and exact file list. The
user must approve before Pi gives those paths to the mutation stage. The stage
cannot edit other paths.

## Bundled refinement workflows

Both bundled workflows have two stages:

1. `refine` reads the request and only the relevant project evidence. It returns
   a complete proposal and exact file list.
2. `write` applies the approved proposal to those files.

There is no separate discovery, audit, investigation, synthesis, conversation,
or verification stage. The workflow makes two model calls in the normal case.
The writer does not run verification commands.

`/refine-spec [idea or area]` proposes edits to project specifications and
closely related documentation. With no input, it selects one clear defect from
active specifications instead of running a broad audit.

`/refine-plan [specification or area]` proposes one concise implementation plan.
The proposal names required files, symbols, behavior, data flow, errors, tests,
and documentation changes. With no input, it selects one clear plan gap instead
of auditing every implementation detail.

## Limits

Prompts and artifact requests use Pi's 50 KB and 2,000-line limits. A workflow
run stops after 100 stage invocations. Project workflow schemas use a portable
subset of JSON Schema.
