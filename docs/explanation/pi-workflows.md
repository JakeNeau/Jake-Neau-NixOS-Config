# Why Pi workflows use isolated stages and artifacts

A Pi workflow must preserve relevant findings without filling one context window
with every exploration path, tool result, and rejected idea. The workflow
manager therefore separates control from reasoning.

The interactive Pi session acts as the control plane. It owns user decisions,
routing, progress, validation, and cleanup. Each bounded reasoning stage runs
in a fresh child Pi process. A conversation mode keeps one child for its full
chat. Every child receives declared artifacts and a catalog of other available
artifacts.

This split keeps the parent context clean. It also makes each stage's input and
output inspectable. A later stage receives conclusions because a prior stage
recorded them, not because both stages happen to share a long transcript.

## Why artifacts replace transcript chaining

Passing a complete child transcript to another stage would recreate the
context problem under another name. It would also mix evidence, intermediate
reasoning, tool noise, and final conclusions. A conversation child retains its
own transcript only while that mode remains active.

A workflow artifact contains a bounded summary and a schema-checked payload.
The parent adds identity and lineage. Later stages can request an undeclared
artifact explicitly when the default input set is insufficient.

This hybrid rule avoids two failure modes:

- sending every prior result to every stage
- losing an important finding because a workflow author did not predict one
  dependency

Pi records artifacts as custom session entries. Users can inspect them, but the
parent model never receives them automatically.

## Why the execution graph stays acyclic

Some workflows repeat stage types. The refinement workflows may ask several
questions, rerun an audit, or repair one failed verification. A static
stage-type graph therefore needs cycles.

Each concrete invocation still receives a new identity and can depend only on
earlier artifacts. The run forms an acyclic graph even when the same stage type
appears several times.

This distinction makes retries and iterations auditable. It also prevents a
stage from rewriting history or creating a self-referential input.

## Why workflows constrain routing

An unrestricted orchestrator could jump to an unsafe writer, skip required
verification, or invent a stage name. A purely fixed chain would prevent those
errors but could not adapt to evidence.

Workflow definitions declare allowed successor sets. When several sets are
valid, a fresh router child chooses among only those sets and states its reason.
The engine validates the choice before scheduling anything.

A set can contain several stages. Pi runs safe read-only branches concurrently
and combines them at a declared join. User approvals and stop decisions always
override model routing.

## Why workflows inherit model choices

A workflow describes a procedure, not a model preset. The user chooses the
model and thinking level before starting the run. Pi snapshots those values for
every child stage in that run.

This rule keeps workflow behavior independent from provider preference. It also
prevents a project workflow from selecting a more expensive or differently
trusted model.

## Why project workflows are declarative

Trusted project workflows can still grant tools and supply agent instructions,
so project trust remains mandatory. The first implementation uses JSON,
Markdown, and JSON Schema rather than project TypeScript.

A data-first definition exposes stages, routes, joins, tools, and mutation
boundaries to validation before the workflow runs. Executable project code
would make those guarantees harder to inspect and would add another extension
loader inside the workflow manager.

## Why read-only command exceptions are project-local

A conservative Bash policy cannot predict every project validation command.
Some useful checks also create caches or build outputs, so a universal list
would either block valid work or permit excessive behavior.

A trusted project may therefore grant command prefixes to one read-only stage.
The workflow manager rejects shell composition and keeps file mutation tools
blocked. This design makes the weaker boundary visible beside the project
workflow without turning it into a global exception.

## Why mutation follows approval

The model may propose several specification files. That proposal does not
authorize writes. `refine-spec` first shows the complete design and exact file
set to the user.

After approval, Pi hashes those files. Pi gives the writer only their exact
paths. A concurrent change invalidates approval. A fresh verifier compares the
written specifications with project evidence and every recorded user decision.

The result is slower than letting one long-running agent edit immediately. The
extra stages buy context isolation, explicit decisions, bounded authority, and
independent verification.

## Why clarification and exploration are separate

Clarification and exploration assign initiative to different actors.
Clarification lets the model identify missing requirements and ask one focused
question at a time. Exploration lets the user develop an idea through open
discussion without entering a model-led interview.

Combining these behaviors caused two failures. Exploration behaved like a
series of isolated clarification requests. The model could also decide that an
exploration invalidated a question and return to clarification without the
user's request.

The refinement runtime now keeps the modes separate. Slash commands and
explicit natural-language instructions can switch between clarification,
exploration, and writing. Discussion, suggestions, and questions do not trigger
a transition. The model can report uncertainty, but it cannot select the next
stage.

Each conversation mode keeps one child process alive across turns. The child
retains the normal chat transcript, model snapshot, tool policy, and supplied
evidence. This removes repeated process startup and evidence serialization from
every conversational turn.

When the user requests a stage change, the child emits one bounded summary.
Later stages receive the summary instead of the complete transcript. This keeps
the artifact graph bounded without making each message a one-off question.

## Why specification and plan refinement share one engine

Specification and plan refinement have the same safety and decision lifecycle.
Both discover project practice, gather independent evidence, and ask one
question at a time. Both approve exact paths, hash files, write with bounded
authority, and verify in a fresh stage.

Separate control paths would make retries, approval, and mutation policy drift.
The workflow manager therefore runs both definitions through one refinement
engine. Separate prompts and schemas define their different artifacts.

A specification decides intended behavior. An implementation plan decides the
exact coding procedure for that behavior. The plan workflow therefore requires
file, symbol, data-flow, error, test, and documentation details. It also confines
the plan to the specification's directory.
