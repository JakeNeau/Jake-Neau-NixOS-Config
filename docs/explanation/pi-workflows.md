# Why Pi workflows use isolated stages and artifacts

A Pi workflow must preserve useful results without filling the parent context
with child tool output. The workflow manager therefore separates control from
reasoning.

The interactive Pi session owns routing, user decisions, progress, and cleanup.
Each reasoning stage runs in a fresh child Pi process. A stage returns one
schema-checked artifact instead of its transcript.

## Why artifacts replace transcript chaining

A complete child transcript mixes evidence, intermediate reasoning, tool noise,
and conclusions. Passing that transcript to another stage recreates the same
context problem in a different process.

An artifact contains a bounded summary and payload. The parent adds identity and
lineage. Later stages receive declared artifacts and may request an omitted
artifact when needed.

This design keeps workflow results inspectable without sending every prior
result to every stage.

## Why workflows constrain routing

Workflow definitions declare allowed successor sets. A fixed successor runs
directly. When several sets are valid, a router child chooses only among those
sets.

A set may contain parallel read-only stages. Mutation stages and user decisions
remain serial. This structure permits useful branching without allowing a model
to invent a stage or bypass approval. Read-only stages are advisory, so parallel
read-only branches can still write at the same time.

A route matches only a key that the `transitions` object itself defines. A
JavaScript object also inherits names such as `constructor`. An outcome with
that name would otherwise look routed and fail later in the run. Pi therefore
rejects it at load time and at runtime.

## Why workflows inherit model choices

A workflow describes a procedure, not a model preset. Pi snapshots the user's
model and thinking level when a run starts. Every child uses that snapshot.

This rule prevents a project workflow from choosing a more expensive or
separately trusted model.

## Why project workflows are declarative

Trusted projects can define workflows that grant tools and instruct agents. JSON,
Markdown, and JSON Schema expose those permissions and routes before Pi runs them.
Executable project code would make the boundary harder to inspect.

## Why mutation follows approval

A proposal does not authorize writes. Pi shows the proposed design and exact
file list. After approval, the writer can edit only those paths.

This boundary preserves the essential safety property without adding a separate
verification workflow.

Read-only stages are advisory. Their prompt tells the agent not to change
anything, and no tool enforces it. The user chose this rule, provided each stage
stays under 20% of its context window. The earlier read-only Bash policy also
leaked. Commands such as `find . -name '*.md' -delete` and
`git branch -D main` passed it. Removing the policy is simpler than patching
every leak.

Mutation stages keep their enforcement, because they hold write tools after
approval. Their exact tool allowlist keeps Bash out, and a path check limits
`edit` and `write` to the approved files.

### The accepted risk

An untrusted repository's `AGENTS.md`, or any file a stage reads, can steer a
read-only stage into writing files or running commands. The bundled refinement
workflows run in untrusted repositories. The `*` tool set adds three effects:

- `ask_user` is active in the child. A call gets a cancel reply, and the stage
  reads "User cancelled the question.", which it can mistake for the user
  declining.
- A background subagent from pi-subagents can outlive the stage. Its tokens
  fall outside the stage's usage totals and the 20% budget.
- MCP tools default to Pi's internal deferred exposure, so `*` does not
  activate them, and Pi does not declare them to the model. However, `*`
  activates `codemode`, and a `codemode` script can still call the MCP tools.
  These tools include Home Assistant on aspen, redwood, and spruce, and the
  filesystem server on redwood.

The user accepted these risks.

## Why bundled workflows stay short

Pi examines the project. Pi tells the user exactly what it will change. The user
must approve those changes before Pi writes the specification or plan. Pi does not need to audit, investigate, synthesize, converse, retry, and verify
every request in separate stages.

Each bundled refinement workflow therefore uses one reasoning stage and one
writer stage. The reasoning stage can inspect relevant evidence and produce a
complete proposal in one context. The writer then applies the approved text.

This design favors prompt quality and user control over orchestration. It also
keeps the normal run to two model calls.

## Why the context budget warns

A stage child should stay under 20% of its model's context window. The full
tool set of a read-only stage makes the tool definitions larger. The stage
inputs stay bounded. At four characters per token, 50 KB is about 12,800
tokens, or about 6% of a 200,000-token window.

Pi measures each stage's peak request and warns above the budget. It does not
stop the stage, because a hard stop would discard a stage after its tokens were
spent. The user chose the warning.

## Why quitting closes the artifact store

Only Escape and quitting reach a running workflow, because the loader or a
checkpoint dialog replaces the editor. Both paths abort the run.

Escape relies on the abort checks. Pi checks the abort after each child returns
and before it appends the artifact. Escape in a checkpoint dialog cancels the
dialog, which stops the run before any append.

Quitting fires session shutdown, which can arrive while a checkpoint dialog is
still open. That dialog can resolve after the abort, and no abort check stands
between its answer and the append. Quitting therefore also closes the artifact
store, so a late decision, approval, or clarification request cannot join the
run's lineage.

One risk remains. After session shutdown, the old run's interface cleanup and
notifications can still reach a stale context and throw. The store stop removes
the late appends, but not these calls.

## Why the run keeps only its TUI path

Pi refuses to start a workflow outside TUI mode. The loader and the question
checkpoint therefore keep only their TUI paths, and their non-TUI branches are
gone.

The question checkpoint no longer offers "Explore this decision". The runtime
stopped the run for that choice without a reason. The conversation stages that
the option once led to had already left the code.

## Why the workflow manager stays small

A robustness pattern enters only when it prevents a failure that can happen in
this code today. The rpiv-workflow project carries patterns for its own scale
and hosts.
The workflow manager leaves out these patterns.

- **A persistent run trail with resume.** Resume would need the `write` stage
  to repeat safely after a partial edit.
- **In-process stage hosts.** The runner already fails fast on the child's
  failures. The child process keeps its own process group, tool allowlist, and
  clean exit.
- **More validation retries.** One correction matches rpiv-workflow's default.
- **A configurable stage timeout.** No workflow needs a different limit.

Resume stays a non-goal. A lost run costs one `refine` call for the bundled
workflows. A future resume would rebuild a run from its `workflow-artifact`
session entries, which already carry the run identity and lineage.

Each change keeps these properties:

- Approval comes before mutation.
- A mutation stage has no Bash and edits only approved paths.
- `Shift+Tab` cycles the workflow modes.
- Project definitions load only in trusted projects.
- Every stage inherits the user's model and thinking level.
