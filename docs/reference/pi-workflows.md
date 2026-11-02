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

A running workflow holds the editor with its loader or a checkpoint dialog. The
user therefore cannot type `/workflow status` or `/workflow stop` during a run.
Escape and quitting Pi are the only ways to reach a running workflow. Each one
stops the run.

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

Pi shows each definition diagnostic as a warning that starts with the path of
the file at fault. It shows the first five and counts the rest.

Pi no longer reads `.pi/workflows/read-only-exceptions.json`. When a trusted
project still has the file, Pi reports this diagnostic:

```text
<path>: read-only-exceptions.json is no longer used, because read-only stages are prompt-only
```

A definition that sets `readOnlyCommandPrefixes` fails to load.

A workflow cannot set a model, provider, or thinking level. Pi snapshots the
active model and thinking level when the run starts.

## Stage definitions

Each stage in `workflow.json` defines:

| Field | Meaning |
|---|---|
| `prompt` | Markdown prompt path relative to the workflow directory |
| `tools` | Exact child tool allowlist for a mutation stage. Optional for a read-only stage, which ignores its value. When present, it must be a string array, or the definition fails with `tools must be strings`. |
| `readOnly` | Whether the stage is read-only. The prompt tells a read-only stage not to change anything, and no tool enforces it. |
| `inputs` | Artifact kinds included in the stage prompt |
| `outputSchema` | Portable JSON schema for `workflow_output` |
| `transitions` | Output outcomes mapped to allowed successor sets |
| `join` | Optional `all` or `any` branch join |
| `mutationPaths` | Required marker for mutation stages |
| `checkpoint` | Optional `question` or `proposal` user checkpoint |

A successor set is an array of stage names. A transition may offer several
sets. Pi asks a router child to select among them. Several names in one set form
a fork. An empty transition list ends the workflow for that outcome.

Each `outcome` value that a stage's output schema lists in `enum` or `const`
needs its own key in `transitions`. Otherwise the definition fails to load with
`stage <name> outcome has no route: <outcome>`. A stage named `clarify` is
exempt, because Pi never routes its outcome.

Read-only branches may run concurrently. `maxParallel` limits the run. Mutation
and user-decision stages run serially. When one parallel branch fails, Pi stops
its sibling branches and starts no new branch from that batch.

## Child stages and artifacts

Each stage uses a fresh `pi --mode rpc --no-session` child process. The child
receives the project directory, trust decision, model snapshot, stage prompt,
selected artifacts, artifact catalog, and tool set.

The tool set depends on the stage:

- A mutation stage receives its `tools` list plus the two workflow tools.
- A read-only stage receives `--tools *`. The `*` pattern activates every
  built-in and extension tool, including `codemode`. MCP tools keep Pi's
  internal deferred exposure, so `*` does not activate them, and Pi does not
  declare them to the model. A `codemode` script can still call them.
- The router child receives only the two workflow tools.

The child process registers two workflow tools:

- `workflow_output` validates and returns the stage artifact.
- `request_workflow_artifacts` loads up to three earlier artifacts within a
  combined 50 KB limit.

Both workflow tools are model-only. The model calls them directly, but a
`codemode` script cannot call them.

The parent validates `workflow_output` again. Invalid or missing output receives
one correction prompt. The correction also covers these errors:

- an outcome with no route
- a router choice outside the allowed successor sets
- a question payload that lacks a field that the question dialog reads

A route lookup uses only the transitions' own keys. An outcome named
`constructor` or `toString` therefore has no route. A second failure stops the
stage and lists every error on one line:

```text
Invalid workflow artifact after repair: <error>; <error>
```

A stage fails at once, without a correction, in these cases:

- The child rejects the prompt, for example because no model or API key is
  set. The stage reports the child's error.
- An extension or command in the child handles the prompt without starting a
  run.
- The last assistant message ends with a provider error, and the stage has no
  valid artifact. The stage reports the provider's error message.
- The child exits before the correction.

A `select`, `confirm`, `input`, or `editor` dialog in the child receives a
cancel reply, because nobody can answer it. A cancelled `confirm` reads as
`false`. Each attempt has its own 10-minute timeout.

The parent assigns each artifact a run identity, stage identity, parent
identities, timestamp, kind, outcome, summary, and payload. Parents must already
exist. Pi stores artifacts as non-context session entries. The TUI shows an
ordinary artifact as a compact entry and reveals its payload when expanded. A
proposal checkpoint uses a review entry that shows the complete design.

Escape or quitting Pi stops the run. Pi stops each child and removes its
temporary files. After Escape, Pi checks the abort before each append, so a
stage that finishes late records no artifact. Pi then reports
`Workflow stopped: <name>` without an error toast. After quitting, that notice
can reach a context that no longer exists. Quitting also closes the run's
artifact store, so a dialog that resolves after quitting records no decision,
approval, or clarification request.

When a stage fails, its error toast shows only the first line of the error, cut
at 200 characters.

Artifacts stay on the branch where the run happened. Pi never reads them back.
A `write` stage's edits stay on disk and follow no branch.

| Path after a run | Effect |
|---|---|
| `/tree` to an earlier entry | The artifacts stay on the old branch. `/workflow restart` reruns the last workflow from the new point. |
| `/fork` or `/clone` | The copy includes the artifacts. `/workflow restart` has no last workflow. |
| `/new`, `/resume`, or `pi -c` | `/workflow restart` has no last workflow. |
| `/reload` | `/workflow restart` has no last workflow. |
| Compaction | Artifacts are not model context, so compaction leaves them as they are. |

None of these paths can run during a workflow. Quitting is the only exit, and
it stops the run.

## Question checkpoints

A stage with `"checkpoint": "question"` that returns a `question` artifact opens
the ask-user dialog. The payload's `question` object must contain:

- `text` and `why` strings
- a non-empty `options` array whose items have string `label` and
  `consequence` fields
- an optional `recommendation` string or `null`

The dialog title shows the text, the reason, and the recommendation. Each
option renders as `<label> — <consequence>`. The dialog adds the free-form and
clarifying-question rows. Pi removes bare carriage returns from the question and
labels.

- A preset option or a free-form answer records a `decision-record` artifact,
  and the run continues.
- A clarifying question records a `clarification-request` artifact. When the
  workflow has a stage named `clarify`, Pi runs it and shows its answer. Pi then
  asks the question again. Without a `clarify` stage, Pi warns and asks again.
- Escape stops the run.

The `clarify` stage needs no route for its outcomes.

## Mutation policy

Read-only stages are advisory. Pi appends this sentence to each read-only stage
prompt:

```text
This stage is read-only: do not change files, the project, or the system.
```

No tool enforces it. A read-only stage receives every tool, including Bash,
`edit`, and `write`.

Mutation stages may use `edit` and `write`. Their `tools` list may name only
approved mutation tools, and that list excludes Bash. The exact allowlist is
the only thing that keeps Bash out. A proposal checkpoint shows the design and
exact file list. The user must approve before Pi gives those paths to the
mutation stage. The stage cannot edit other paths.

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

Each attempt of a stage has its own 10-minute timeout. A stage with a
correction can therefore take about 20 minutes.

Pi measures each stage's peak context use. For each assistant message, the
request size is `usage.totalTokens`, or the sum of input, output, cache-read,
and cache-write tokens. The peak is the largest request across both attempts.
Pi warns when the peak exceeds 20% of the model's context window:

```text
<stage> used <n>% of the context window, above the 20% budget
```

`<n>` is `Math.ceil((peak * 100) / contextWindow)`, so the percentage rounds up.
The warning follows these rules:

- Each stage gets at most one warning.
- The warning never stops the stage.
- The router child gets no warning.
- A stage that fails never reaches the warning.
- No warning appears when the model's context window is unknown.
