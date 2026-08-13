# Add a project-local Pi workflow

Use a project workflow when a repository needs a repeatable, staged procedure.
The project must be trusted before Pi loads it.

## 1. Create the workflow tree

Create one directory under `.pi/workflows/`:

```text
.pi/workflows/review-change/
  workflow.json
  stages/inspect.md
  stages/report.md
  schemas/inspect.json
  schemas/report.json
```

Use a lowercase workflow name with letters, digits, and hyphens. Do not use a
built-in Pi command name.

## 2. Define the graph

Create `workflow.json`:

```json
{
  "version": 1,
  "name": "review-change",
  "description": "Inspect a change and produce a verified report",
  "inputHint": "<change to review>",
  "color": "warning",
  "entry": "inspect",
  "terminalOutcomes": ["done"],
  "maxParallel": 2,
  "stages": {
    "inspect": {
      "prompt": "stages/inspect.md",
      "tools": ["read", "grep", "find", "ls"],
      "readOnly": true,
      "inputs": ["workflow-input"],
      "outputSchema": "schemas/inspect.json",
      "transitions": {
        "ready": [["report"]]
      }
    },
    "report": {
      "prompt": "stages/report.md",
      "tools": ["read", "bash"],
      "readOnly": true,
      "inputs": ["review-evidence"],
      "outputSchema": "schemas/report.json",
      "transitions": {
        "done": []
      }
    }
  }
}
```

Each transition value contains allowed successor sets. `[["report"]]` has one
possible set with one stage. `[["spec-scout", "code-scout"]]` forks into two
stages. An empty list ends a terminal outcome.

Do not add model, provider, or thinking fields. The workflow inherits those
choices from the user.

## 3. Write each stage prompt

Tell the child what evidence to use and which artifact to return. End with an
explicit `workflow_output` instruction.

```markdown
# Inspect the requested change

Read the supplied workflow input and relevant files. Identify correctness,
safety, and integration findings. Support every finding with a source path.

Return one `review-evidence` artifact with `workflow_output`.
```

A child can call `request_workflow_artifacts` for an earlier artifact omitted
from its declared `inputs`. It must supply artifact identities and a reason.

## 4. Define portable output schemas

Each schema describes the complete `workflow_output` arguments. Require the
standard fields:

```json
{
  "type": "object",
  "additionalProperties": false,
  "required": ["artifactKind", "outcome", "summary", "payload"],
  "properties": {
    "artifactKind": { "enum": ["review-evidence"] },
    "outcome": { "enum": ["ready"] },
    "summary": { "type": "string", "minLength": 1, "maxLength": 1000 },
    "payload": {
      "type": "object",
      "additionalProperties": false,
      "required": ["findings"],
      "properties": {
        "findings": {
          "type": "array",
          "maxItems": 20,
          "items": { "type": "string", "maxLength": 1000 }
        }
      }
    }
  }
}
```

Use only the supported schema fields shown in
[the workflow reference](../reference/pi-workflows.md). Keep every string and
array bounded.

## 5. Add forks and joins when needed

Put several stages in one successor set to create a fork:

```json
"transitions": {
  "ready": [["spec-scout", "code-scout"]]
}
```

Give the join stage a policy:

```json
"join": {
  "mode": "all",
  "stages": ["spec-scout", "code-scout"]
}
```

Use `all` when every branch is required. Use `any` only when the first useful
branch can continue safely.

## 6. Add user checkpoints

Set `"checkpoint": "question"` when the stage returns the standard question
payload used by `refine-spec`. Pi presents the choices and records the answer as
a new artifact.

Set `"checkpoint": "proposal"` before a mutation stage. The proposal payload
must contain `files`, with one `path` per requested mutation. Pi asks for
approval and gives later mutation stages only those exact paths.

A mutation stage must set `"readOnly": false`, list `mutationPaths`, and omit
Bash unless the procedure requires it. Read-only stages receive a conservative
Bash policy even when they list the Bash tool.

## 7. Add a read-only Bash exception

Add `.pi/workflows/read-only-exceptions.json` when a read-only stage must run a
project validation command that the default policy blocks:

```json
{
  "version": 1,
  "workflows": {
    "review-change": {
      "report": {
        "allowedCommandPrefixes": ["nix flake check", "cargo test"]
      }
    }
  }
}
```

The named stage must set `readOnly` to `true` and include `bash` in `tools`.
Scope each prefix to the narrowest command form that supports the stage.
Arguments may follow a prefix. Pi still blocks shell composition, redirection,
command substitution, and multiline commands.

Trust the project before Pi loads the policy. One invalid entry rejects the
complete exception file, and Pi reports a workflow diagnostic. Exceptions
never permit `edit` or `write` in a read-only stage.

## 8. Replace a global workflow explicitly

A project workflow cannot shadow a global workflow accidentally. Add `replaces`
when replacement is intentional:

```json
{
  "name": "refine-spec",
  "replaces": "refine-spec"
}
```

Pi shows the project source in the active mode label.

## 9. Reload and run

Trust the project, then run `/reload`. Use `/workflow` to inspect available
modes.

Arm the workflow with `Shift+Tab`, then submit its input. You can also run it
directly:

```text
/workflow run review-change inspect the current branch
```

Use `/workflow status` during the run. Use `/workflow stop` or Escape to abort
it.
