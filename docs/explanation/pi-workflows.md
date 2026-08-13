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
to invent a stage or bypass approval.

## Why workflows inherit model choices

A workflow describes a procedure, not a model preset. Pi snapshots the user's
model and thinking level when a run starts. Every child uses that snapshot.

This rule prevents a project workflow from choosing a more expensive or
separately trusted model.

## Why project workflows are declarative

Trusted projects can define workflows that grant tools and instruct agents. JSON,
Markdown, and JSON Schema expose those permissions and routes before Pi runs them.
Executable project code would make the boundary harder to inspect.

A project may add narrow Bash prefixes for a read-only stage. Pi still rejects
shell composition and keeps mutation tools blocked.

## Why mutation follows approval

A proposal does not authorize writes. Pi shows the proposed design and exact
file list. After approval, the writer can edit only those paths.

This boundary preserves the essential safety property without adding a separate
verification workflow.

## Why bundled workflows stay short

Pi examines the project. Pi tells the user exactly what it will change. The user
must approve those changes before Pi writes the specification or plan. Pi does not need to audit, investigate, synthesize, converse, retry, and verify
every request in separate stages.

Each bundled refinement workflow therefore uses one reasoning stage and one
writer stage. The reasoning stage can inspect relevant evidence and produce a
complete proposal in one context. The writer then applies the approved text.

This design favors prompt quality and user control over orchestration. It also
keeps the normal run to two model calls.
