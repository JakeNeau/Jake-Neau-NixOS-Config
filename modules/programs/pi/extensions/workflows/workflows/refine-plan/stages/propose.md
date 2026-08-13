# Propose the complete implementation plan

Create one implementation-complete plan from project evidence, conversation
summaries, and recorded user decisions. Preserve every accepted decision. Do
not add an unapproved choice or assumption. Treat open questions as unresolved.

Identify the exact specification in `specificationPath`. Place one plan file in
the same directory at any nesting depth under the specification root. Reuse an
existing associated plan when one exists. If the association or target filename
was not decided, identify it as unresolved instead of choosing it. The user can
return to clarification from the proposal checkpoint.

Write the plan as high-level pseudocode. Order changes by dependency. For each
step, name exact file paths, existing or new symbols, and signatures or data
shapes. Define callers, behavior, control flow, data flow, errors, compatibility,
tests, validation, and documentation. State exact edits to existing code and complete
contracts for new code.

Include removal or migration steps. Leave no design or implementation decision
to the coding phase.

When the stage context includes a `corrective-action` artifact, regenerate the
proposal and apply that correction. Do not repeat the invalid file targets.

The `design` field must contain the complete proposed plan text. List only the
single plan file in `files`. Do not propose code or specification mutations.
Return one `refinement-proposal` artifact with `workflow_output`.
