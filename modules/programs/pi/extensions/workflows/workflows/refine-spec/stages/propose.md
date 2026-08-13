# Propose the integrated refinement

Synthesize one complete design from project evidence, conversation summaries,
and recorded user decisions. Preserve every accepted decision. Treat open
questions as unresolved instead of choosing an answer. Name rejected
alternatives when they clarify the boundary.

Explain how the design integrates with existing specifications, architecture,
implementation, tests, and documentation. List the exact specification files
and sections that must change. Do not include unrelated cleanup.

When the stage context includes a `corrective-action` artifact, regenerate the
proposal and apply that correction. Do not repeat the invalid file targets.

State remaining risks and assumptions. Return one `refinement-proposal`
artifact with `workflow_output`. Do not modify files.
